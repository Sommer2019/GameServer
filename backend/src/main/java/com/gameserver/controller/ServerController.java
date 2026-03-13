package com.gameserver.controller;

import com.gameserver.dto.ServerCreateRequest;
import com.gameserver.dto.ServerResponse;
import com.gameserver.service.ServerService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/servers")
public class ServerController {

    private final ServerService serverService;

    public ServerController(ServerService serverService) {
        this.serverService = serverService;
    }

    @PostMapping
    public ResponseEntity<ServerResponse> createServer(
            @AuthenticationPrincipal UserDetails user,
            @Valid @RequestBody ServerCreateRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(serverService.createServer(user.getUsername(), req));
    }

    @GetMapping
    public ResponseEntity<ServerResponse> getServer(@AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(serverService.getServer(user.getUsername()));
    }

    @PostMapping("/start")
    public ResponseEntity<ServerResponse> startServer(@AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(serverService.startServer(user.getUsername()));
    }

    @PostMapping("/stop")
    public ResponseEntity<ServerResponse> stopServer(@AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(serverService.stopServer(user.getUsername()));
    }

    @DeleteMapping
    public ResponseEntity<Void> deleteServer(@AuthenticationPrincipal UserDetails user) {
        serverService.deleteServer(user.getUsername());
        return ResponseEntity.noContent().build();
    }
}
