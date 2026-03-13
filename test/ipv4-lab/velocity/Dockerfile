# =============================================================================
# IPv4 Lab – Velocity Dockerfile
# =============================================================================
# Dedicated test-lab build so the IPv4 setup stays independent from the
# existing production-oriented velocity/ directory in the repo root.
# =============================================================================
FROM eclipse-temurin:21-jre-alpine

ARG VELOCITY_VERSION=3.3.0-SNAPSHOT
ARG VELOCITY_BUILD=388

RUN apk add --no-cache bash busybox-extras

WORKDIR /opt/velocity

ADD https://api.papermc.io/v2/projects/velocity/versions/${VELOCITY_VERSION}/builds/${VELOCITY_BUILD}/downloads/velocity-${VELOCITY_VERSION}-${VELOCITY_BUILD}.jar \
    velocity.jar

COPY velocity.toml /opt/velocity/velocity.toml

VOLUME ["/opt/velocity"]

EXPOSE 25577

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD nc -z localhost 25577 || exit 1

ENTRYPOINT ["java", \
    "-Xms512M", "-Xmx1G", \
    "-XX:+UseG1GC", \
    "-XX:G1HeapRegionSize=4M", \
    "-XX:+UnlockExperimentalVMOptions", \
    "-XX:+ParallelRefProcEnabled", \
    "-XX:+AlwaysPreTouch", \
    "-jar", "velocity.jar"]

