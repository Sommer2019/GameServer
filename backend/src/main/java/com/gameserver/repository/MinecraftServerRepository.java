package com.gameserver.repository;

import com.gameserver.model.MinecraftServer;
import com.gameserver.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;

public interface MinecraftServerRepository extends JpaRepository<MinecraftServer, Long> {
    Optional<MinecraftServer> findByUser(User user);
    boolean existsByUser(User user);
    long count();

    @Query("SELECT m.port FROM MinecraftServer m")
    List<Integer> findAllPorts();
}
