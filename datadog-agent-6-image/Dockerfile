ARG dd_agent_version=6.20.1-jmx
FROM datadog/agent:${dd_agent_version}

###### ATTENTION ######
## The base image uses docker volumes (https://github.com/DataDog/datadog-agent/blob/master/Dockerfiles/agent/Dockerfile#L120),
## this causes modifications to certain folders (currently "/var/run/s6", "/etc/datadog-agent", "/var/log/datadog", "/tmp")
## to be lost when done in RUN commands (but not in COPY as it seems).
##
## See also:
## - https://github.com/moby/moby/issues/37176#issuecomment-470951814
## - https://docs.docker.com/engine/reference/builder/#notes-about-specifying-volumes
##
## This means you have to make sure you don't try to modify anything in these folders!
########################

RUN rm -rf conf.d/

COPY datadog.yaml /etc/datadog-agent/datadog.yaml
COPY conf.d/ /etc/datadog-agent/conf.d/

RUN \
    /opt/datadog-agent/embedded/bin/pip install google-auth google-auth-httplib2 google-api-python-client azure-mgmt-sql azure-mgmt-resource

RUN \
    mkdir -p /usr/local/datadog-agent/lib && \
    # Download and verify checksum of wildfly-client-all (Wildfly-specific JMX client)
    curl -s --fail -L https://repo1.maven.org/maven2/org/wildfly/wildfly-client-all/19.0.0.Final/wildfly-client-all-19.0.0.Final.jar > /usr/local/datadog-agent/lib/jboss-cli-client.jar && \
    (cd /usr/local/datadog-agent/lib && echo "e94f6d22332ad2e658883cee6b03940a73acf22d5655f9544f335ce018a65895  jboss-cli-client.jar" | sha256sum -c -)

USER root
CMD ["/init"]
