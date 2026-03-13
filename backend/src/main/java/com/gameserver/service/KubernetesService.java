package com.gameserver.service;

import io.fabric8.kubernetes.api.model.*;
import io.fabric8.kubernetes.api.model.apps.Deployment;
import io.fabric8.kubernetes.api.model.apps.DeploymentBuilder;import io.fabric8.kubernetes.client.KubernetesClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * Manages Minecraft game servers as Kubernetes Deployments + NodePort Services
 * in the "gameservers" namespace on the same cluster as the web tier.
 *
 * "Stop" = scale Deployment to 0 replicas (container removed, state preserved in DB).
 * "Start" = scale Deployment to 1 replica.
 * "Delete" = delete Deployment + Service.
 */
@Service
@ConditionalOnProperty(name = "app.orchestration", havingValue = "kubernetes")
public class KubernetesService implements ContainerOrchestrationService {

    private static final Logger log = LoggerFactory.getLogger(KubernetesService.class);

    static final String NAMESPACE = "gameservers";
    private static final String MINECRAFT_IMAGE = "itzg/minecraft-server:latest";
    private static final String MINECRAFT_JVM_MEMORY = "768m";

    private final KubernetesClient client;

    @Value("${app.orchestration.kubernetes.node-selector:}")
    private String nodeSelectorLabel; // optional: e.g. "kubernetes.io/os=linux"

    public KubernetesService(KubernetesClient client) {
        this.client = client;
    }

    /**
     * Creates a Kubernetes Deployment (1 replica) and a NodePort Service,
     * then returns the deployment name as the opaque container ID.
     */
    @Override
    public String createMinecraftContainer(String serverName, int nodePort) {
        String depName = toDeploymentName(serverName);
        String svcName = toServiceName(serverName);

        Deployment deployment = new DeploymentBuilder()
                .withNewMetadata()
                    .withName(depName)
                    .withNamespace(NAMESPACE)
                    .addToLabels("app", depName)
                    .addToLabels("managed-by", "gameserver-backend")
                .endMetadata()
                .withNewSpec()
                    .withReplicas(1)
                    .withNewSelector()
                        .addToMatchLabels("app", depName)
                    .endSelector()
                    .withNewTemplate()
                        .withNewMetadata()
                            .addToLabels("app", depName)
                        .endMetadata()
                        .withNewSpec()
                            .addNewContainer()
                                .withName("minecraft")
                                .withImage(MINECRAFT_IMAGE)
                                .withImagePullPolicy("IfNotPresent")
                                .addNewEnv().withName("EULA").withValue("TRUE").endEnv()
                                .addNewEnv().withName("TYPE").withValue("VANILLA").endEnv()
                                .addNewEnv().withName("MEMORY").withValue(MINECRAFT_JVM_MEMORY).endEnv()
                                .addNewEnv().withName("MAX_PLAYERS").withValue("10").endEnv()
                                .addNewEnv().withName("MOTD").withValue(serverName).endEnv()
                                .addNewEnv().withName("ONLINE_MODE").withValue("TRUE").endEnv()
                                .addNewPort()
                                    .withContainerPort(25565)
                                    .withProtocol("TCP")
                                .endPort()
                                .withNewResources()
                                    .addToLimits("memory", new Quantity("1Gi"))
                                    .addToLimits("cpu", new Quantity("1"))
                                    .addToRequests("memory", new Quantity("512Mi"))
                                    .addToRequests("cpu", new Quantity("250m"))
                                .endResources()
                            .endContainer()
                        .endSpec()
                    .endTemplate()
                .endSpec()
                .build();

        client.apps().deployments().inNamespace(NAMESPACE).resource(deployment).create();
        log.info("Created Deployment '{}' in namespace '{}'", depName, NAMESPACE);

        io.fabric8.kubernetes.api.model.Service service = new ServiceBuilder()
                .withNewMetadata()
                    .withName(svcName)
                    .withNamespace(NAMESPACE)
                    .addToLabels("managed-by", "gameserver-backend")
                .endMetadata()
                .withNewSpec()
                    .withType("NodePort")
                    .withSelector(Map.of("app", depName))
                    .addNewPort()
                        .withPort(25565)
                        .withTargetPort(new IntOrString(25565))
                        .withNodePort(nodePort)
                        .withProtocol("TCP")
                    .endPort()
                .endSpec()
                .build();

        client.services().inNamespace(NAMESPACE).resource(service).create();        log.info("Created NodePort Service '{}' (nodePort={}) in namespace '{}'", svcName, nodePort, NAMESPACE);

        return depName;
    }

    /** Scales the Deployment to 1 replica. */
    @Override
    public void startContainer(String deploymentName) {
        client.apps().deployments()
                .inNamespace(NAMESPACE)
                .withName(deploymentName)
                .scale(1);
        log.info("Scaled Deployment '{}' to 1 replica", deploymentName);
    }

    /** Scales the Deployment to 0 replicas (container gone, Service preserved). */
    @Override
    public void stopContainer(String deploymentName) {
        client.apps().deployments()
                .inNamespace(NAMESPACE)
                .withName(deploymentName)
                .scale(0);
        log.info("Scaled Deployment '{}' to 0 replicas", deploymentName);
    }

    /** Deletes the Deployment and its associated NodePort Service. */
    @Override
    public void removeContainer(String deploymentName) {
        client.apps().deployments().inNamespace(NAMESPACE).withName(deploymentName).delete();
        String svcName = deploymentToServiceName(deploymentName);
        client.services().inNamespace(NAMESPACE).withName(svcName).delete();
        log.info("Deleted Deployment '{}' and Service '{}'", deploymentName, svcName);
    }

    /**
     * Maps Deployment ready-replica state to a normalised status string
     * compatible with {@link com.gameserver.model.ServerStatus} mapping in ServerService.
     */
    @Override
    public String getContainerState(String deploymentName) {
        try {
            var dep = client.apps().deployments()
                    .inNamespace(NAMESPACE)
                    .withName(deploymentName)
                    .get();
            if (dep == null) return "unknown";

            Integer desired = dep.getSpec().getReplicas();
            Integer ready   = dep.getStatus().getReadyReplicas();

            if (desired == null || desired == 0) return "exited";
            if (ready != null && ready >= desired)  return "running";
            return "created"; // scaling up / starting
        } catch (Exception e) {
            log.warn("Could not get state for Deployment '{}': {}", deploymentName, e.getMessage());
            return "unknown";
        }
    }

    // ── Naming helpers ──────────────────────────────────────────────────────────

    private static String toDeploymentName(String serverName) {
        // Kubernetes names: lowercase alphanumeric + '-', max 63 chars
        String base = "mc-" + serverName.toLowerCase().replaceAll("[^a-z0-9-]", "-");
        String cleaned = base.replaceAll("-{2,}", "-").replaceAll("-$", "");
        return cleaned.substring(0, Math.min(63, cleaned.length()));
    }

    private static String toServiceName(String serverName) {
        return "svc-" + toDeploymentName(serverName).replaceFirst("^mc-", "");
    }

    private static String deploymentToServiceName(String deploymentName) {
        return "svc-" + deploymentName.replaceFirst("^mc-", "");
    }
}
