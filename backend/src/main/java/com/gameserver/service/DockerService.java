package com.gameserver.service;

import com.github.dockerjava.api.DockerClient;
import com.github.dockerjava.api.command.CreateContainerResponse;
import com.github.dockerjava.api.command.InspectContainerResponse;
import com.github.dockerjava.api.model.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class DockerService {

    private static final Logger log = LoggerFactory.getLogger(DockerService.class);
    private static final String MINECRAFT_IMAGE = "itzg/minecraft-server:latest";
    private static final long MEMORY_LIMIT_BYTES = 1_073_741_824L; // 1 GB hard limit for the container
    private static final String MINECRAFT_JVM_MEMORY = "768m";     // JVM heap (leaves ~256 MB for OS overhead)
    private static final long NANO_CPUS = 1_000_000_000L;          // 1 vCPU

    private final DockerClient dockerClient;

    public DockerService(DockerClient dockerClient) {
        this.dockerClient = dockerClient;
    }

    /**
     * Pulls the Minecraft image if not present, creates a container and returns its ID.
     */
    public String createMinecraftContainer(String serverName, int hostPort) {
        pullImageIfAbsent(MINECRAFT_IMAGE);

        ExposedPort containerPort = ExposedPort.tcp(25565);
        Ports portBindings = new Ports();
        portBindings.bind(containerPort, Ports.Binding.bindPort(hostPort));

        HostConfig hostConfig = HostConfig.newHostConfig()
                .withPortBindings(portBindings)
                .withMemory(MEMORY_LIMIT_BYTES)
                .withNanoCPUs(NANO_CPUS)
                .withNetworkMode("bridge")
                .withRestartPolicy(RestartPolicy.noRestart());

        CreateContainerResponse container = dockerClient.createContainerCmd(MINECRAFT_IMAGE)
                .withName(sanitizeContainerName(serverName))
                .withEnv(
                        "EULA=TRUE",
                        "TYPE=VANILLA",
                        "MEMORY=" + MINECRAFT_JVM_MEMORY,
                        "MAX_PLAYERS=10",
                        "MOTD=" + serverName,
                        "ONLINE_MODE=TRUE"
                )
                .withExposedPorts(containerPort)
                .withHostConfig(hostConfig)
                .exec();

        log.info("Created Minecraft container {} for server '{}'", container.getId(), serverName);
        return container.getId();
    }

    public void startContainer(String containerId) {
        dockerClient.startContainerCmd(containerId).exec();
        log.info("Started container {}", containerId);
    }

    public void stopContainer(String containerId) {
        dockerClient.stopContainerCmd(containerId).withTimeout(30).exec();
        log.info("Stopped container {}", containerId);
    }

    public void removeContainer(String containerId) {
        dockerClient.removeContainerCmd(containerId).withForce(true).exec();
        log.info("Removed container {}", containerId);
    }

    /**
     * Returns the Docker container state string (e.g. "running", "exited").
     */
    public String getContainerState(String containerId) {
        try {
            InspectContainerResponse inspect = dockerClient.inspectContainerCmd(containerId).exec();
            return inspect.getState().getStatus();
        } catch (Exception e) {
            log.warn("Could not inspect container {}: {}", containerId, e.getMessage());
            return "unknown";
        }
    }

    private void pullImageIfAbsent(String image) {
        try {
            dockerClient.pullImageCmd(image)
                    .start()
                    .awaitCompletion();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("Image pull interrupted for {}", image);
        } catch (Exception e) {
            log.warn("Could not pull image {}: {}", image, e.getMessage());
        }
    }

    private String sanitizeContainerName(String name) {
        // Container names must match [a-zA-Z0-9_.-]
        return "mc-" + name.replaceAll("[^a-zA-Z0-9_.-]", "_");
    }
}
