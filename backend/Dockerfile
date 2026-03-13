# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
# Download dependencies first (layer caching)
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn package -DskipTests -q

# ---- Runtime stage ----
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Create non-root user for security
RUN addgroup -S gameserver && adduser -S gameserver -G gameserver

COPY --from=build /app/target/gameserver-backend-1.0.0.jar app.jar

RUN mkdir -p /data && chown gameserver:gameserver /data
USER gameserver

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
