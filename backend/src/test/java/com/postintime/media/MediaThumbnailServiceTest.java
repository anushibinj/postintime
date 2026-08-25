package com.postintime.media;

import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MediaThumbnailServiceTest {

    private final MediaThumbnailService service = new MediaThumbnailService();

    @Test
    void resizeSquareProducesRequestedDimensions() throws Exception {
        byte[] png = Base64.getDecoder().decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC");
        MediaThumbnailService.Thumbnail thumb = service.resizeSquare(png, 32);
        assertThat(thumb.contentType()).isEqualTo("image/jpeg");
        BufferedImage image = ImageIO.read(new ByteArrayInputStream(thumb.bytes()));
        assertThat(image.getWidth()).isEqualTo(32);
        assertThat(image.getHeight()).isEqualTo(32);
        assertThat(thumb.bytes().length).isLessThan(png.length * 20);
    }

    @Test
    void requireValidSizeRejectsOutOfRange() {
        assertThatThrownBy(() -> service.requireValidSize(8))
                .hasMessageContaining("between");
        assertThatThrownBy(() -> service.requireValidSize(1024))
                .hasMessageContaining("between");
        assertThat(service.requireValidSize(64)).isEqualTo(64);
    }

    @Test
    void resizeSquareWorksForJpegSource() throws Exception {
        BufferedImage source = new BufferedImage(120, 80, BufferedImage.TYPE_INT_RGB);
        ByteArrayOutputStream jpegOut = new ByteArrayOutputStream();
        ImageIO.write(source, "jpg", jpegOut);
        MediaThumbnailService.Thumbnail thumb = service.resizeSquare(jpegOut.toByteArray(), 48);
        BufferedImage image = ImageIO.read(new ByteArrayInputStream(thumb.bytes()));
        assertThat(image.getWidth()).isEqualTo(48);
        assertThat(image.getHeight()).isEqualTo(48);
    }
}
