package com.gameserver.config;

import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.KubernetesClientBuilder;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "app.orchestration", havingValue = "kubernetes")
public class KubernetesConfig {

    /**
     * Fabric8 KubernetesClient auto-configures from:
     * - in-cluster: ServiceAccount token at /var/run/secrets/kubernetes.io/serviceaccount/
     * - outside cluster: ~/.kube/config (or KUBECONFIG env var)
     */
    @Bean
    public KubernetesClient kubernetesClient() {
        return new KubernetesClientBuilder().build();
    }
}
