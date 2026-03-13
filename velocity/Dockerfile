# =============================================================================
# Velocity Proxy – Dockerfile
# =============================================================================
# Builds a container image for the Velocity proxy.
# The proxy must be reachable from the internet on port 25577 (or 25565).
#
# Build:
#   docker build -t gameserver-velocity ./velocity
# Run:
#   docker run -d --name velocity \
#     -p 25577:25577 \
#     -v $(pwd)/velocity/velocity.toml:/opt/velocity/velocity.toml:ro \
#     -v velocity-data:/opt/velocity \
#     gameserver-velocity
# =============================================================================
FROM eclipse-temurin:21-jre-alpine

ARG VELOCITY_VERSION=3.3.0-SNAPSHOT
ARG VELOCITY_BUILD=388

WORKDIR /opt/velocity

# Download Velocity JAR
ADD https://api.papermc.io/v2/projects/velocity/versions/${VELOCITY_VERSION}/builds/${VELOCITY_BUILD}/downloads/velocity-${VELOCITY_VERSION}-${VELOCITY_BUILD}.jar \
    velocity.jar

# Copy configuration (can be overridden via volume mount at runtime)
COPY velocity.toml /opt/velocity/velocity.toml

# Velocity data directory
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
