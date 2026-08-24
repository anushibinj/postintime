package com.postintime.publishing.domain;

public record PublishResult(
        boolean success,
        String externalPostId,
        String externalUrl,
        String errorCode,
        String errorMessage
) {
    public static PublishResult manualInstructions() {
        return new PublishResult(true, null, null, null, null);
    }

    public static PublishResult ok() {
        return new PublishResult(true, null, null, null, null);
    }

    public static PublishResult failure(String errorCode, String errorMessage) {
        return new PublishResult(false, null, null, errorCode, errorMessage);
    }
}
