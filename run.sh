#!/bin/bash

set -euo pipefail

NS=datadog-agent
#LOG_TIMEOUT="60s"

waitForPodReady() {
  podName="$1"
  timeout=60
  sleep 1
  while [ $timeout -gt 0 ]; do
    if kubectl -n $NS get pods | fgrep "Running" | fgrep "1/1" | fgrep "$podName" > /dev/null; then
      return 0
    else 
      timeout=$((timeout-1))
      sleep 1
    fi
  done
  return 1
}


waitForPodDeletion() {
  podName="$1"
  timeout=60
  while [ $timeout -gt 0 ]; do
    if kubectl -n $NS get pods | egrep "Running|Terminating" | fgrep "$podName" > /dev/null; then
      timeout=$((timeout-1))
      sleep 1
    else 
      return 0
    fi
  done
  return 1
}

startAgent() {
  kubectl apply -f pods/agent.yaml
  kubectl -n $NS rollout status deployment/datadog-agent
}

stopAgent() {
  podName="$(getAgentPodName)"
  kubectl delete --wait=true -f pods/agent.yaml
  waitForPodDeletion "$podName"
}

startWildfly() {
  kubectl apply -f pods/wildfly.yaml
  kubectl -n $NS rollout status deployment/wildfly
}

stopWildfly() {
  podName="$(getWildflyPodName)"
  kubectl delete --wait=true -f pods/wildfly.yaml
  waitForPodDeletion "$podName"
}

restartWildfly() {
  podName="$(getWildflyPodName)"
  kubectl -n $NS exec "$podName" -- /bin/bash -c "kill 1"
  waitForPodReady "$podName"
}

deleteWildflyPod() {
  podName="$(getWildflyPodName)"
  kubectl -n $NS delete pod "$podName"
  waitForPodDeletion "$podName"
  podName="$(getWildflyPodName)"
  waitForPodReady "$podName"
}

getAgentPodName() {
  echo "$(kubectl -n $NS get pods | grep "Running" | egrep -o "datadog-agent-[^ ]+")"
}

getWildflyPodName() {
  echo "$(kubectl -n $NS get pods | grep "Running" | egrep -o "wildfly-[^ ]+")"
}

#grepAgentLogs() {
#  logFile="$1"
#  agentPod="$(getAgentPodName)"
#  kubectl -n $NS logs -f $agentPod | tee -a "\"$logFile\""
  #if [ "$(timeout "$LOG_TIMEOUT" bash -c "$cmd" | wc -l)" = "$count" ]; then
  #  echo "success"
  #else
  #  echo "fail"
  #fi
#}

runTest() {
  config=$1
  testName=$(basename "$config")
  echo "[$(date +"%H:%M:%S")] Running test ${testName}"
  echo "-------------------------"
  # clear any existing logs
  mkdir -p "logs/${testName}"
  rm "logs/${testName}"/* > /dev/null 2>&1 || true
  source "$config"
  
  # Test restarting the pod when the agent is already running
  startWildfly > /dev/null
  startAgent > /dev/null
  sleep 5
  restartWildfly
  
  echo -n "[$(date +"%H:%M:%S")] Pod: restart, Agent: running => "
 # grepAgentLogs "logs/${testName}/ddagent-jmx.log"
  kubectl -n $NS logs -f "$(getAgentPodName)" | tee -a "logs/${testName}/ddagent-jmx.log"
  echo "Over"

  #stopWildfly > /dev/null
  #stopAgent > /dev/null
  echo -e "\n"
}

echo "Build image"
docker build -t ddagent-jmx datadog-agent-6-image
docker build -t wildfly-jmx wildfly-image

echo -e "\n"

echo "Setting up"
for file in setup/*; do
  kubectl apply -f "$file"
done
echo -e "\n"

echo -e "Running tests\n"
for file in tests/*; do
  runTest "$file"
done

echo "shutting down"
#kubectl delete ns $NS
