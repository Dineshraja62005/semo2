package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.HashMap;
import java.util.Map;

@RestController
public class MessageController {
    
    private final String deploymentColor = System.getenv("DEPLOYMENT_COLOR") != null ? 
                                           System.getenv("DEPLOYMENT_COLOR") : "unknown";
    
    // Root path endpoint
    @GetMapping("/")
    public String home() {
        return "Welcome to My Spring Boot Application with Blue-Green Deployment! (Running on " + deploymentColor + " environment)";
    }

    // Additional endpoint for demonstration
    @GetMapping("/hello")
    public String hello() {
        return "Hello, World! This is a simple Spring Boot message from the " + deploymentColor + " environment.";
    }

    // Fun endpoint with current time
    @GetMapping("/time")
    public String currentTime() {
        return "Current Server Time: " + new java.util.Date().toString() + " (from " + deploymentColor + " environment)";
    }
    
    // Endpoint that returns information as JSON
    @GetMapping("/info")
    public Map<String, String> info() {
        Map<String, String> info = new HashMap<>();
        info.put("application", "Spring Boot Demo");
        info.put("version", "1.0.0");
        info.put("environment", deploymentColor);
        info.put("timestamp", new java.util.Date().toString());
        return info;
    }
    
    // Health check endpoint
    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> health = new HashMap<>();
        health.put("status", "UP");
        health.put("environment", deploymentColor);
        return health;
    }
}