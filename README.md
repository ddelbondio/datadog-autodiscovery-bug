# Datadog Autodiscovery bug when using Docker labels in Kubernetes

When using Docker labels for autodiscovery there is a race condition in the agent which causes it to fail to discover the Pod after a crash or a restart.

This happens with all kind of configuration combinations.

The relevant error seems to be 

```
[ AGENT ] 2019-04-03 12:36:46 UTC | WARN | (pkg/autodiscovery/autoconfig.go:529 in resolveTemplateForService) | error resolving template apache for service docker://c7fa540faf5ed71cb2186af54e513514dbfb03ae7505b05ee393546722c29d12: failed to extract IP address for container docker://c7fa540faf5ed71cb2186af54e513514dbfb03ae7505b05ee393546722c29d12, ignoring it. Source error: "container docker://c7fa540faf5ed71cb2186af54e513514dbfb03ae7505b05ee393546722c29d12 in PodList" not found
```

# Versions
## Docker
```
Server:
 Version:      17.03.2-ce
 API version:  1.27 (minimum version 1.12)
 Go version:   go1.7.5
 Git commit:   f5ec1e2
 Built:        Tue Jun 27 02:31:19 2017
 OS/Arch:      linux/amd64
 Experimental: false
```

## Kubernetes
```
Server Version: version.Info{
 Major:"1",
 Minor:"10", 
 GitVersion:"v1.10.11", 
 GitCommit:"637c7e288581ee40ab4ca210618a89a555b6e7e9", 
 GitTreeState:"clean", 
 BuildDate:"2018-11-26T14:25:46Z", 
 GoVersion:"go1.9.3", 
 Compiler:"gc", 
 Platform:"linux/amd64"
}
```
```
Client Version: version.Info{
 Major:"1", 
 Minor:"14", 
 GitVersion:"v1.14.0", 
 GitCommit:"641856db18352033a0d96dbc99153fa3b27298e5", 
 GitTreeState:"clean", 
 BuildDate:"2019-03-25T15:53:57Z", 
 GoVersion:"go1.12.1", 
 Compiler:"gc", 
 Platform:"linux/amd64"
}
```
# Running the repro case

You need a running kubernetes cluster on the same host as the test script. The script will use the local Docker daemon for the created images and requires a kubectl to be set up to connect the local cluster.

Datadog logs for each test are written to logs/ folder.

# Test results
The tests where performed with the versions listed above on debian (9.8) and a kubernetes cluster started with minikube (`minikube start --vm-driver=none --kubernetes-version=v1.10.11`)

```
Build image
Sending build context to Docker daemon 2.048 kB
Step 1/2 : FROM httpd
 ---> d4a07e6ce470
Step 2/2 : LABEL com.datadoghq.ad.check.id httpd
 ---> Using cache
 ---> 9d5486c65cd5
Successfully built 9d5486c65cd5


Setting up
namespace/datadog-agent unchanged
serviceaccount/datadog-agent unchanged
clusterrole.rbac.authorization.k8s.io/datadog-agent unchanged
clusterrolebinding.rbac.authorization.k8s.io/datadog-agent unchanged
deployment.extensions/fake-datadog unchanged
service/fake-datadog unchanged


Running tests

[14:12:03] Running test 01_listender_kubelet-config_kubelet.yaml
-------------------------
[14:12:09] Pod: running, Agent: start => fail
[14:13:26] Pod: start, Agent: running => fail
[14:14:49] Pod: restart, Agent: running => fail
[14:16:00] Pod: delete, Agent: running => fail


[14:17:10] Running test 02_listener_kubelet-config_kubelet_docker.yaml
-------------------------
[14:17:16] Pod: running, Agent: start => fail
[14:18:40] Pod: start, Agent: running => fail
[14:20:07] Pod: restart, Agent: running => fail
[14:21:16] Pod: delete, Agent: running => fail


[14:22:33] Running test 03_listener_kubelet_docker-config_kubelet.yaml
-------------------------
[14:22:39] Pod: running, Agent: start => success
[14:23:18] Pod: start, Agent: running => success
[14:23:49] Pod: restart, Agent: running => fail
[14:25:00] Pod: delete, Agent: running => fail


[14:26:21] Running test 04_listener_kubelet_docker-config_kubelet_docker.yaml
-------------------------
[14:26:27] Pod: running, Agent: start => success
[14:27:01] Pod: start, Agent: running => success
[14:27:35] Pod: restart, Agent: running => fail
[14:28:50] Pod: delete, Agent: running => fail


shutting down
```