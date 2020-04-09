FROM jboss/wildfly:19.0.0.Final

LABEL com.datadoghq.ad.check.id=jmx-remote

COPY standalone.xml /opt/jboss/wildfly/standalone/configuration/

COPY sleep.sh /opt/jboss/wildfly/bin/

CMD ["/bin/sh", "/opt/jboss/wildfly/bin/sleep.sh"]