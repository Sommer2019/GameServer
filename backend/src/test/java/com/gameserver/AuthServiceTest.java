package com.gameserver;

import com.gameserver.dto.LoginRequest;
import com.gameserver.dto.RegisterRequest;
import com.gameserver.model.User;
import com.gameserver.repository.UserRepository;
import com.gameserver.security.JwtUtil;
import com.gameserver.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private JwtUtil jwtUtil;

    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, jwtUtil);
    }

    @Test
    void register_newUser_returnsToken() {
        when(userRepository.existsByUsername("bob")).thenReturn(false);
        when(userRepository.existsByEmail("bob@example.com")).thenReturn(false);
        when(userRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(jwtUtil.generateToken("bob")).thenReturn("tok123");

        RegisterRequest req = new RegisterRequest();
        req.setUsername("bob");
        req.setPassword("securepass");
        req.setEmail("bob@example.com");

        var response = authService.register(req);

        assertThat(response.getToken()).isEqualTo("tok123");
        assertThat(response.getUsername()).isEqualTo("bob");
    }

    @Test
    void register_duplicateUsername_throwsIllegalArgument() {
        when(userRepository.existsByUsername("bob")).thenReturn(true);

        RegisterRequest req = new RegisterRequest();
        req.setUsername("bob");
        req.setPassword("pass");
        req.setEmail("other@example.com");

        assertThatThrownBy(() -> authService.register(req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Username already taken");
    }

    @Test
    void register_duplicateEmail_throwsIllegalArgument() {
        when(userRepository.existsByUsername("newuser")).thenReturn(false);
        when(userRepository.existsByEmail("dup@example.com")).thenReturn(true);

        RegisterRequest req = new RegisterRequest();
        req.setUsername("newuser");
        req.setPassword("pass");
        req.setEmail("dup@example.com");

        assertThatThrownBy(() -> authService.register(req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Email already registered");
    }

    @Test
    void login_validCredentials_returnsToken() {
        String raw = "mypassword";
        String hashed = passwordEncoder.encode(raw);
        User user = new User("alice", hashed, "alice@example.com");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user));
        when(jwtUtil.generateToken("alice")).thenReturn("jwt-abc");

        LoginRequest req = new LoginRequest();
        req.setUsername("alice");
        req.setPassword(raw);

        var response = authService.login(req);

        assertThat(response.getToken()).isEqualTo("jwt-abc");
    }

    @Test
    void login_wrongPassword_throwsBadCredentials() {
        String hashed = passwordEncoder.encode("correct");
        User user = new User("alice", hashed, "alice@example.com");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(user));

        LoginRequest req = new LoginRequest();
        req.setUsername("alice");
        req.setPassword("wrong");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(BadCredentialsException.class);
    }

    @Test
    void login_unknownUser_throwsBadCredentials() {
        when(userRepository.findByUsername("ghost")).thenReturn(Optional.empty());

        LoginRequest req = new LoginRequest();
        req.setUsername("ghost");
        req.setPassword("pass");

        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(BadCredentialsException.class);
    }
}
