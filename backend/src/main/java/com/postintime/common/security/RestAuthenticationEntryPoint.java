package com.postintime.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.postintime.common.api.ApiErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    public RestAuthenticationEntryPoint(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        ApiErrorResponse body = new ApiErrorResponse(
                Instant.now().toString(),
                HttpServletResponse.SC_UNAUTHORIZED,
                "AUTH_FAILED",
                "Authentication required. Send Authorization: Bearer <token>.",
                List.of(),
                request.getHeader("X-Request-Id") != null
                        ? request.getHeader("X-Request-Id")
                        : UUID.randomUUID().toString()
        );
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getOutputStream(), body);
    }
}
