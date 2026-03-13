package com.gameserver;

import com.gameserver.dto.ServerCreateRequest;
import com.gameserver.model.MinecraftServer;
import com.gameserver.model.ServerStatus;
import com.gameserver.model.User;
import com.gameserver.repository.MinecraftServerRepository;
import com.gameserver.repository.UserRepository;
import com.gameserver.service.DockerService;
import com.gameserver.service.ServerService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ServerServiceTest {

    @Mock
    private MinecraftServerRepository serverRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private DockerService dockerService;

    private ServerService serverService;

    private final User testUser = new User("alice", "hashed", "alice@example.com");

    @BeforeEach
    void setUp() {
        serverService = new ServerService(serverRepository, userRepository, dockerService);
        testUser.setId(1L);
    }

    @Test
    void createServer_happyPath_createsAndStartsContainer() {
        // Arrange
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.existsByUser(testUser)).thenReturn(false);
        when(serverRepository.count()).thenReturn(0L);
        when(serverRepository.findAllPorts()).thenReturn(List.of());
        when(dockerService.createMinecraftContainer(eq("MyServer"), eq(25565))).thenReturn("container123");
        when(serverRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ServerCreateRequest req = new ServerCreateRequest();
        req.setName("MyServer");

        // Act
        var response = serverService.createServer("alice", req);

        // Assert
        assertThat(response.getName()).isEqualTo("MyServer");
        assertThat(response.getPort()).isEqualTo(25565);
        assertThat(response.getStatus()).isEqualTo(ServerStatus.RUNNING);
        verify(dockerService).createMinecraftContainer("MyServer", 25565);
        verify(dockerService).startContainer("container123");
    }

    @Test
    void createServer_userAlreadyHasServer_throwsIllegalState() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.existsByUser(testUser)).thenReturn(true);

        ServerCreateRequest req = new ServerCreateRequest();
        req.setName("Second");

        assertThatThrownBy(() -> serverService.createServer("alice", req))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("already have a server");
    }

    @Test
    void createServer_maxTotalServersReached_throwsIllegalState() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.existsByUser(testUser)).thenReturn(false);
        when(serverRepository.count()).thenReturn(10L);

        ServerCreateRequest req = new ServerCreateRequest();
        req.setName("Overflow");

        assertThatThrownBy(() -> serverService.createServer("alice", req))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Maximum number of servers");
    }

    @Test
    void createServer_allPortsOccupied_throwsIllegalState() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.existsByUser(testUser)).thenReturn(false);
        when(serverRepository.count()).thenReturn(9L);
        // All 10 ports taken
        when(serverRepository.findAllPorts()).thenReturn(
                List.of(25565, 25566, 25567, 25568, 25569, 25570, 25571, 25572, 25573, 25574)
        );

        ServerCreateRequest req = new ServerCreateRequest();
        req.setName("NoPort");

        assertThatThrownBy(() -> serverService.createServer("alice", req))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("No available ports");
    }

    @Test
    void createServer_picksLowestFreePort() {
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.existsByUser(testUser)).thenReturn(false);
        when(serverRepository.count()).thenReturn(3L);
        when(serverRepository.findAllPorts()).thenReturn(List.of(25565, 25566, 25567));
        when(dockerService.createMinecraftContainer(any(), eq(25568))).thenReturn("ctr");
        when(serverRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        ServerCreateRequest req = new ServerCreateRequest();
        req.setName("S4");

        var response = serverService.createServer("alice", req);
        assertThat(response.getPort()).isEqualTo(25568);
    }

    @Test
    void deleteServer_removesContainerAndRecord() {
        MinecraftServer server = new MinecraftServer("S", testUser, 25565);
        server.setContainerId("ctr42");
        server.setStatus(ServerStatus.RUNNING);

        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.findByUser(testUser)).thenReturn(Optional.of(server));

        serverService.deleteServer("alice");

        verify(dockerService).removeContainer("ctr42");
        verify(serverRepository).delete(server);
    }

    @Test
    void stopServer_updatesStatusToStopped() {
        MinecraftServer server = new MinecraftServer("S", testUser, 25565);
        server.setContainerId("ctr99");
        server.setStatus(ServerStatus.RUNNING);

        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(testUser));
        when(serverRepository.findByUser(testUser)).thenReturn(Optional.of(server));
        when(serverRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var response = serverService.stopServer("alice");

        assertThat(response.getStatus()).isEqualTo(ServerStatus.STOPPED);
        verify(dockerService).stopContainer("ctr99");
    }
}
