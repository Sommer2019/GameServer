package com.gameserver.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ServerCreateRequest {

    @NotBlank
    @Size(min = 1, max = 50)
    @Pattern(regexp = "^[a-zA-Z0-9_\\-]+$", message = "Server name may only contain letters, digits, hyphens and underscores")
    private String name;
}
