package com.postintime.publishing.publisher;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

class PostmanMultipartBodyTest {

    @Test
    void buildsPostmanStylePartsWithoutTextContentType() throws Exception {
        PostmanMultipartBody multipart = PostmanMultipartBody.create()
                .addFile("media", "banner.png", "image/png", new byte[]{1, 2, 3})
                .addText("title", "Some title")
                .addText("caption", "Some description");

        String body = new String(multipart.build(), StandardCharsets.UTF_8);
        String contentType = multipart.contentTypeHeader();

        assertThat(contentType).matches("multipart/form-data; boundary=-{26}[0-9a-f]{32}");
        assertThat(multipart.boundary()).startsWith("--------------------------");
        assertThat(body).startsWith("--" + multipart.boundary());
        assertThat(body).contains("Content-Disposition: form-data; name=\"media\"; filename=\"banner.png\"");
        assertThat(body).contains("Content-Type: image/png");
        assertThat(body).contains("Content-Disposition: form-data; name=\"title\"");
        assertThat(body).contains("Some title");
        assertThat(body).contains("Content-Disposition: form-data; name=\"caption\"");
        assertThat(body).contains("Some description");

        // Text fields must not carry Content-Type (Postman/Bruno style).
        int titleIndex = body.indexOf("name=\"title\"");
        int captionIndex = body.indexOf("name=\"caption\"");
        int mediaIndex = body.indexOf("name=\"media\"");
        assertThat(mediaIndex).isLessThan(titleIndex);
        assertThat(titleIndex).isLessThan(captionIndex);

        String titlePart = body.substring(titleIndex, captionIndex);
        assertThat(titlePart).doesNotContain("Content-Type:");
        String captionPart = body.substring(captionIndex);
        assertThat(captionPart).doesNotContain("Content-Type:");
    }
}
