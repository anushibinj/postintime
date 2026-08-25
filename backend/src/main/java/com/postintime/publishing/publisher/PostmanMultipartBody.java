package com.postintime.publishing.publisher;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

/**
 * Builds multipart/form-data bodies in the same shape Postman/Bruno use:
 * text fields have only Content-Disposition (no Content-Type), file parts include
 * filename + Content-Type. Spring's FormHttpMessageConverter always adds
 * {@code text/plain;charset=UTF-8} on string parts, which some receivers (n8n) drop.
 */
final class PostmanMultipartBody {

    private static final byte[] CRLF = "\r\n".getBytes(StandardCharsets.UTF_8);

    private final String boundary;
    private final ByteArrayOutputStream buffer = new ByteArrayOutputStream();

    private PostmanMultipartBody(String boundary) {
        this.boundary = boundary;
    }

    static PostmanMultipartBody create() {
        return new PostmanMultipartBody("----postintime" + UUID.randomUUID().toString().replace("-", ""));
    }

    String contentType() {
        return "multipart/form-data; boundary=" + boundary;
    }

    PostmanMultipartBody addText(String name, String value) throws IOException {
        writeBoundary();
        writeLine("Content-Disposition: form-data; name=\"" + escape(name) + "\"");
        writeLine("");
        buffer.write((value == null ? "" : value).getBytes(StandardCharsets.UTF_8));
        buffer.write(CRLF);
        return this;
    }

    PostmanMultipartBody addFile(String name, String filename, String contentType, byte[] bytes) throws IOException {
        writeBoundary();
        writeLine("Content-Disposition: form-data; name=\"" + escape(name)
                + "\"; filename=\"" + escape(filename == null ? "file" : filename) + "\"");
        writeLine("Content-Type: " + (contentType == null || contentType.isBlank()
                ? "application/octet-stream"
                : contentType));
        writeLine("");
        buffer.write(bytes);
        buffer.write(CRLF);
        return this;
    }

    byte[] build() throws IOException {
        buffer.write(("--" + boundary + "--").getBytes(StandardCharsets.UTF_8));
        buffer.write(CRLF);
        return buffer.toByteArray();
    }

    private void writeBoundary() throws IOException {
        buffer.write(("--" + boundary).getBytes(StandardCharsets.UTF_8));
        buffer.write(CRLF);
    }

    private void writeLine(String line) throws IOException {
        buffer.write(line.getBytes(StandardCharsets.UTF_8));
        buffer.write(CRLF);
    }

    private static String escape(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
