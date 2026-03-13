package com.gameserver.service;

import com.gameserver.dto.ServerCreateRequest;
import com.gameserver.dto.ServerResponse;
import com.gameserver.model.MinecraftServer;
import com.gameserver.model.ServerStatus;
import com.gameserver.model.User;
import com.gameserver.repository.MinecraftServerRepository;
import com.gameserver.repository.UserRepository;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.IntStream;

@Service
public class ServerService {

    static final int MAX_TOTAL_SERVERS = 10;
    static final int PORT_RANGE_START = 25565;
    static final int PORT_RANGE_END = 25574; // inclusive, 10 ports total

    private final MinecraftServerRepository serverRepository;
    private final UserRepository userRepository;
    private final DockerService dockerService;

    public ServerService(MinecraftServerRepository serverRepository,
                         UserRepository userRepository,
                         DockerService dockerService) {
        this.serverRepository = serverRepository;
        this.userRepository = userRepository;
        this.dockerService = dockerService;
    }

    @Transactional
    public ServerResponse createServer(String username, ServerCreateRequest req) {
        User user = findUser(username);

        if (serverRepository.existsByUser(user)) {
            throw new IllegalStateException("You already have a server. Only one server per account is allowed.");
        }
        if (serverRepository.count() >= MAX_TOTAL_SERVERS) {
            throw new IllegalStateException("Maximum number of servers (" + MAX_TOTAL_SERVERS + ") reached.");
        }

        int port = allocatePort();
        MinecraftServer server = new MinecraftServer(req.getName(), user, port);
        serverRepository.save(server);

        try {
            String containerId = dockerService.createMinecraftContainer(req.getName(), port);
            server.setContainerId(containerId);
            dockerService.startContainer(containerId);
            server.setStatus(ServerStatus.RUNNING);
        } catch (Exception e) {
            server.setStatus(ServerStatus.ERROR);
        }

        serverRepository.save(server);
        return toResponse(server);
    }

    @Transactional(readOnly = true)
    public ServerResponse getServer(String username) {
        User user = findUser(username);
        MinecraftServer server = serverRepository.findByUser(user)
                .orElseThrow(() -> new IllegalStateException("No server found for this account."));
        syncStatus(server);
        return toResponse(server);
    }

    @Transactional
    public ServerResponse startServer(String username) {
        MinecraftServer server = getServerEntity(username);
        if (server.getContainerId() == null) {
            throw new IllegalStateException("Server has no associated container.");
        }
        dockerService.startContainer(server.getContainerId());
        server.setStatus(ServerStatus.RUNNING);
        serverRepository.save(server);
        return toResponse(server);
    }

    @Transactional
    public ServerResponse stopServer(String username) {
        MinecraftServer server = getServerEntity(username);
        if (server.getContainerId() == null) {
            throw new IllegalStateException("Server has no associated container.");
        }
        dockerService.stopContainer(server.getContainerId());
        server.setStatus(ServerStatus.STOPPED);
        serverRepository.save(server);
        return toResponse(server);
    }

    @Transactional
    public void deleteServer(String username) {
        MinecraftServer server = getServerEntity(username);
        if (server.getContainerId() != null) {
            dockerService.removeContainer(server.getContainerId());
        }
        serverRepository.delete(server);
    }

    private MinecraftServer getServerEntity(String username) {
        User user = findUser(username);
        return serverRepository.findByUser(user)
                .orElseThrow(() -> new IllegalStateException("No server found for this account."));
    }

    private User findUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
    }

    private int allocatePort() {
        List<Integer> usedPorts = serverRepository.findAllPorts();
        return IntStream.rangeClosed(PORT_RANGE_START, PORT_RANGE_END)
                .filter(p -> !usedPorts.contains(p))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("No available ports for a new server."));
    }

    private void syncStatus(MinecraftServer server) {
        if (server.getContainerId() != null) {
            String state = dockerService.getContainerState(server.getContainerId());
            ServerStatus status = switch (state) {
                case "running" -> ServerStatus.RUNNING;
                case "exited", "dead" -> ServerStatus.STOPPED;
                case "created", "paused", "restarting" -> ServerStatus.CREATING;
                default -> ServerStatus.ERROR;
            };
            if (status != server.getStatus()) {
                server.setStatus(status);
                serverRepository.save(server);
            }
        }
    }

    private ServerResponse toResponse(MinecraftServer server) {
        return new ServerResponse(
                server.getId(),
                server.getName(),
                server.getPort(),
                server.getStatus(),
                server.getCreatedAt()
        );
    }
}
