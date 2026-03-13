package com.gameserver.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "minecraft_servers")
@Getter
@Setter
@NoArgsConstructor
public class MinecraftServer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String name;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "container_id")
    private String containerId;

    @Column(nullable = false)
    private Integer port;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ServerStatus status;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public MinecraftServer(String name, User user, Integer port) {
        this.name = name;
        this.user = user;
        this.port = port;
        this.status = ServerStatus.CREATING;
        this.createdAt = LocalDateTime.now();
    }
}
