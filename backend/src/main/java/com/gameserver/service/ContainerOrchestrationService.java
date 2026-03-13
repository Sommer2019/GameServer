package com.gameserver.service;

/**
 * Abstraction over the container runtime.
 * Two implementations exist:
 *  - DockerService     (active when app.orchestration=docker)
 *  - KubernetesService (active when app.orchestration=kubernetes)
 *
 * <p>Implementations must return one of the following normalised state strings
 * from {@link #getContainerState(String)}:
 * <ul>
 *   <li>{@code "running"}   – container/deployment is healthy and accepting connections</li>
 *   <li>{@code "exited"}    – container/deployment was stopped cleanly (Docker: "exited", K8s: scaled to 0)</li>
 *   <li>{@code "dead"}      – container terminated abnormally (Docker only)</li>
 *   <li>{@code "created"}   – container/deployment exists but is not yet ready (starting up, "paused", "restarting")</li>
 *   <li>{@code "unknown"}   – state could not be determined</li>
 * </ul>
 */
public interface ContainerOrchestrationService {

    /**
     * Creates and starts a Minecraft server container/deployment.
     *
     * @param serverName human-readable name
     * @param port       host port (Docker) or NodePort (Kubernetes) to expose
     * @return an opaque identifier used for subsequent operations (containerId or deployment name)
     */
    String createMinecraftContainer(String serverName, int port);

    /** Starts / scales-up a previously stopped container/deployment. */
    void startContainer(String id);

    /** Stops / scales-down a running container/deployment. */
    void stopContainer(String id);

    /** Permanently removes the container/deployment and its associated resources. */
    void removeContainer(String id);

    /**
     * Returns a normalised state string: "running", "exited", "created", or "unknown".
     */
    String getContainerState(String id);
}
