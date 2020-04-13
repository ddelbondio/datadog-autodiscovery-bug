# Datadog JMX metrics collection bug after payload pod restart in Kubernetes

In the occurrence of payload Kubernetes pod restart the JMX metrics collection does not resume. It seems to be related to JMXFetch instance initialization

The relevant error seems to be

```
2020-04-13 09:40:12 UTC | CORE | INFO | (pkg/jmxfetch/jmxfetch.go:248 in func1) | 2020-04-13 09:40:12,115 | WARN  | App | No instance could be initiated. Retrying initialization.
```

## Versions

### Docker

```
Server: Docker Engine - Community
 Engine:
  Version:          19.03.8
  API version:      1.40 (minimum version 1.12)
  Go version:       go1.12.17
  Git commit:       afacb8b
  Built:            Wed Mar 11 01:29:16 2020
  OS/Arch:          linux/amd64
  Experimental:     true
```

### Kubernetes

```
"clientVersion": {
  "major": "1",
  "minor": "15",
  "gitVersion": "v1.15.11",
  "gitCommit": "d94a81c724ea8e1ccc9002d89b7fe81d58f89ede",
  "gitTreeState": "clean",
  "buildDate": "2020-03-12T21:08:59Z",
  "goVersion": "go1.12.17",
  "compiler": "gc",
  "platform": "linux/amd64"
},
"serverVersion": {
  "major": "1",
  "minor": "16+",
  "gitVersion": "v1.16.6-beta.0",
  "gitCommit": "e7f962ba86f4ce7033828210ca3556393c377bcc",
  "gitTreeState": "clean",
  "buildDate": "2020-01-15T08:18:29Z",
  "goVersion": "go1.13.5",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

## Running the repro case

You need a running kubernetes cluster on the same host as the test script. The script will use the local Docker daemon for the created images and requires a kubectl to be set up to connect the local cluster.

Datadog logs for the test are written to logs/ folder.

## Test results

The tests where performed with the versions listed above on debian (9.12) and a Kubernetes cluster running on Docker Desktop with WSL 2 backend

```
Build image
sha256:6868f97297db0e3826154d982fb9cd8a80b85c474ee944498c83a5642f86c96e
sha256:d353cafb59a45efa98c88d6d403a268a411b7c1f61e384c690685d07722f465a


Setting up
namespace/datadog-agent created
serviceaccount/datadog-agent created
clusterrole.rbac.authorization.k8s.io/datadog-agent unchanged
clusterrolebinding.rbac.authorization.k8s.io/datadog-agent unchanged
deployment.apps/fake-datadog created
service/fake-datadog created


Running tests

[12:38:21] Running test
-------------------------
[12:38:24] Agent: running, JVM: no restart => success


[12:39:17] Agent: running, JVM: restart => fail


shutting down
namespace "datadog-agent" deleted
```
