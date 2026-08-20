package com.postintime.common.error;

import com.postintime.common.api.ApiErrorDetail;
import com.postintime.common.api.ApiErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse> handleValidation(MethodArgumentNotValidException ex,
                                                             HttpServletRequest request) {
        List<ApiErrorDetail> details = ex.getBindingResult().getFieldErrors().stream()
                .map(this::toDetail)
                .toList();
        return buildResponse(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                "One or more fields are invalid.", details, request);
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiErrorResponse> handleUnsupportedContentType(
            HttpMediaTypeNotSupportedException ex, HttpServletRequest request) {
        String message = ex.getMessage() != null ? ex.getMessage() : "Content-Type is not supported.";
        return buildResponse(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "CONTENT_TYPE_NOT_SUPPORTED",
                message, List.of(), request);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiErrorResponse> handleMethodNotSupported(
            HttpRequestMethodNotSupportedException ex, HttpServletRequest request) {
        String message = ex.getMessage() != null ? ex.getMessage() : "HTTP method is not supported.";
        return buildResponse(HttpStatus.METHOD_NOT_ALLOWED, "METHOD_NOT_SUPPORTED",
                message, List.of(), request);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiErrorResponse> handleUnreadableMessage(
            HttpMessageNotReadableException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                "Request body is missing or invalid.", List.of(), request);
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiErrorResponse> handleMissingParam(
            MissingServletRequestParameterException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                ex.getMessage(), List.of(), request);
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiErrorResponse> handleBusiness(BusinessException ex, HttpServletRequest request) {
        HttpStatus status = mapBusinessStatus(ex.getCode());
        return buildResponse(status, ex.getCode(), ex.getMessage(), List.of(), request);
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiErrorResponse> handleNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        return buildResponse(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", ex.getMessage(), List.of(), request);
    }

    @ExceptionHandler(com.postintime.common.error.AccessDeniedException.class)
    public ResponseEntity<ApiErrorResponse> handleAccessDenied(com.postintime.common.error.AccessDeniedException ex,
                                                               HttpServletRequest request) {
        return buildResponse(HttpStatus.FORBIDDEN, "ACCESS_DENIED", ex.getMessage(), List.of(), request);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiErrorResponse> handleSpringAccessDenied(AccessDeniedException ex,
                                                                     HttpServletRequest request) {
        return buildResponse(HttpStatus.FORBIDDEN, "ACCESS_DENIED", "Access denied.", List.of(), request);
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ApiErrorResponse> handleBadCredentials(BadCredentialsException ex,
                                                                 HttpServletRequest request) {
        return buildResponse(HttpStatus.UNAUTHORIZED, "AUTH_FAILED", "Invalid email or password.",
                List.of(), request);
    }

    private ApiErrorDetail toDetail(FieldError error) {
        return new ApiErrorDetail(error.getField(), "INVALID", error.getDefaultMessage());
    }

    private HttpStatus mapBusinessStatus(String code) {
        return switch (code) {
            case "CHANNEL_DISABLED", "ACCOUNT_DISABLED", "INVALID_TARGET", "CROSS_CHANNEL_TARGET",
                 "INVALID_STATE", "MEDIA_TOO_LARGE", "UNSUPPORTED_MEDIA_TYPE" -> HttpStatus.BAD_REQUEST;
            case "PUBLISH_FAILED", "PROVIDER_ERROR" -> HttpStatus.UNPROCESSABLE_ENTITY;
            case "RATE_LIMITED" -> HttpStatus.TOO_MANY_REQUESTS;
            case "AUTH_EXPIRED" -> HttpStatus.UNAUTHORIZED;
            default -> HttpStatus.BAD_REQUEST;
        };
    }

    private ResponseEntity<ApiErrorResponse> buildResponse(HttpStatus status, String code, String message,
                                                           List<ApiErrorDetail> details,
                                                           HttpServletRequest request) {
        String requestId = request.getHeader("X-Request-Id");
        if (requestId == null || requestId.isBlank()) {
            requestId = UUID.randomUUID().toString();
        }
        ApiErrorResponse body = new ApiErrorResponse(
                Instant.now().toString(),
                status.value(),
                code,
                message,
                details,
                requestId
        );
        return ResponseEntity.status(status).body(body);
    }
}
