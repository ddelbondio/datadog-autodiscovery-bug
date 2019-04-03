#!/bin/bash

set -euo pipefail

NS=datadog-agent
LOG_TIMEOUT="60s"

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

startHttpd() {
  kubectl apply -f pods/httpd.yaml
  kubectl -n $NS rollout status deployment/httpd
}

stopHttpd() {
  podName="$(getHttpdPodName)"
  kubectl delete --wait=true -f pods/httpd.yaml
  waitForPodDeletion "$podName"
}

restartHttpd() {
  podName="$(getHttpdPodName)"
  kubectl -n $NS exec "$podName" -- /bin/bash -c "kill 1"
  waitForPodReady "$podName"
}

deleteHttpdPod() {
  podName="$(getHttpdPodName)"
  kubectl -n $NS delete pod "$podName"
  waitForPodDeletion "$podName"
}

getAgentPodName() {
  echo $(kubectl -n $NS get pods | grep "Running" | egrep -o "datadog-agent-[^ ]+")
}

getHttpdPodName() {
  echo $(kubectl -n $NS get pods | grep "Running" | egrep -o "httpd-[^ ]+")
}

grepAgentLogs() {
  logFile="$1"
  text="$2"
  count="$3"
  agentPod="$(getAgentPodName)"
  cmd="kubectl -n $NS logs -f $agentPod | tee -a "\"$logFile\"" | stdbuf -oL grep -m $count "\"$text\"" | head -n $count"
  if [ $(timeout "$LOG_TIMEOUT" bash -c "$cmd" | wc -l) = "$count" ]; then
    echo "success"
  else
    echo "fail"
  fi
}

runTest() {
  configmap=$1
  testName=$(basename "$configmap")
  echo "[$(date +"%H:%M:%S")] Running test ${testName}"
  echo "-------------------------"
  # clear any existing logs
  mkdir -p "logs/${testName}"
  rm "logs/${testName}"/* > /dev/null 2>&1 || true
  kubectl apply -f $configmap > /dev/null
  
  # Test starting the agent when a pod is running
  startHttpd > /dev/null
  startAgent > /dev/null
  
  echo -n "[$(date +"%H:%M:%S")] Pod: running, Agent: start => "
  grepAgentLogs "logs/${testName}/pod_running-agent_start.log" "Scheduling check apache with an interval" 1
  
  stopAgent > /dev/null
  stopHttpd > /dev/null
  
  # Test starting the pod when the agent is already running
  startAgent > /dev/null
  startHttpd > /dev/null
  
  echo -n "[$(date +"%H:%M:%S")] Pod: start, Agent: running => "
  grepAgentLogs "logs/${testName}/pod_start-agent_running.log" "Scheduling check apache with an interval" 1

  stopAgent > /dev/null
  stopHttpd > /dev/null

  # Test restarting the pod when the agent is already running
  startHttpd > /dev/null
  startAgent > /dev/null
  restartHttpd
  
  echo -n "[$(date +"%H:%M:%S")] Pod: restart, Agent: running => "
  grepAgentLogs "logs/${testName}/pod_restart-agent_running.log" "Scheduling check apache with an interval" 2

  # Test deleting the pod when the agent is already running
  startHttpd > /dev/null
  startAgent > /dev/null
  deleteHttpdPod > /dev/null
  
  echo -n "[$(date +"%H:%M:%S")] Pod: delete, Agent: running => "
  grepAgentLogs "logs/${testName}/pod_delete-agent_running.log" "Scheduling check apache with an interval" 2
  
  stopHttpd > /dev/null
  stopAgent > /dev/null
  echo -e "\n"
}

echo "Build image"
docker build -t httpd-autodicovery autodiscover-image
echo -e "\n"

echo "Setting up"
for file in setup/*; do
  kubectl apply -f $file
done
echo -e "\n"

echo -e "Running tests\n"
for file in tests/*; do
  runTest $file
done

echo "shutting down"
kubectl delete ns datadog-agent
