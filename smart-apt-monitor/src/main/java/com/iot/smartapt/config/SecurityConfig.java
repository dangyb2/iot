package com.iot.smartapt.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                // 1. Enable CORS (Fixes the Flutter "Failed to fetch" error)
                .cors(Customizer.withDefaults())

                // 2. Disable CSRF (Standard for IoT/REST APIs)
                .csrf(csrf -> csrf.disable())

                // 3. Setup Role-Based Access Control (Rubric Section 4.4)
                .authorizeHttpRequests(auth -> auth
                        // Anyone with a login can view the dashboard data
                        .requestMatchers(HttpMethod.GET, "/api/data").hasAnyRole("ADMIN", "USER", "GUEST")

                        // ONLY Admins and Users can trigger the physical hardware
                        .requestMatchers(HttpMethod.POST, "/api/control/**").hasAnyRole("ADMIN", "USER")

                        // Block everything else just to be safe
                        .anyRequest().authenticated()
                )
                // Use standard Basic Auth popup/headers
                .httpBasic(Customizer.withDefaults());

        return http.build();
    }

    @Bean
    public UserDetailsService userDetailsService() {
        PasswordEncoder encoder = PasswordEncoderFactories.createDelegatingPasswordEncoder();

        // Create Admin User (Can read data & click buttons)
        UserDetails admin = User.withUsername("admin")
                .password(encoder.encode("admin123"))
                .roles("ADMIN")
                .build();

        // Create Standard User (Can read data & click buttons)
        UserDetails user = User.withUsername("user")
                .password(encoder.encode("user123"))
                .roles("USER")
                .build();

        // Create Guest User (Can ONLY read data, cannot click buttons)
        UserDetails guest = User.withUsername("guest")
                .password(encoder.encode("guest123"))
                .roles("GUEST")
                .build();

        return new InMemoryUserDetailsManager(admin, user, guest);
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // Allow Flutter to connect from localhost (or anywhere in dev)
        configuration.setAllowedOrigins(List.of("*"));

        // Allow standard GET/POST, plus OPTIONS (the hidden pre-flight check Flutter does)
        configuration.setAllowedMethods(List.of("GET", "POST", "OPTIONS"));
        configuration.setAllowedHeaders(List.of("Authorization", "Content-Type"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}