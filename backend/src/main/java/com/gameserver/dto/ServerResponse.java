package com.gameserver.dto;

import com.gameserver.model.ServerStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@AllArgsConstructor
public class ServerResponse {
    private Long id;
    private String name;
    private Integer port;
    private ServerStatus status;
    private LocalDateTime createdAt;
}
