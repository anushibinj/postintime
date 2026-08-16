package com.postintime.auth;

import com.postintime.common.error.BusinessException;
import com.postintime.common.security.JwtTokenProvider;
import com.postintime.user.User;
import com.postintime.user.UserRepository;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final AuthenticationManager authenticationManager;

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       JwtTokenProvider jwtTokenProvider,
                       AuthenticationManager authenticationManager) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.authenticationManager = authenticationManager;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BusinessException("VALIDATION_ERROR", "Email is already registered.");
        }
        User user = new User();
        user.setEmail(request.email().toLowerCase());
        user.setDisplayName(request.displayName() != null ? request.displayName() : request.email());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        userRepository.save(user);
        return toAuthResponse(user);
    }

    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.email().toLowerCase(), request.password()));
        User user = userRepository.findByEmail(request.email().toLowerCase())
                .orElseThrow(() -> new BusinessException("AUTH_FAILED", "Invalid email or password."));
        return toAuthResponse(user);
    }

    private AuthResponse toAuthResponse(User user) {
        String token = jwtTokenProvider.generateToken(user.getId(), user.getEmail());
        return new AuthResponse(token, user.getId(), user.getEmail(), user.getDisplayName());
    }
}
