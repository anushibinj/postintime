package com.postintime.social;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class FooterTextTest {

    @Test
    void normalizeDefaultsToEmptyAndCollapsesLineEndings() {
        assertThat(FooterText.normalize(null)).isEmpty();
        assertThat(FooterText.normalize("  a\r\nb\rc  ")).isEqualTo("a\nb\nc");
    }

    @Test
    void everySupportedPlatformUsesLf() {
        for (Platform platform : Platform.values()) {
            assertThat(FooterText.newlineFor(platform)).isEqualTo("\n");
        }
    }

    @Test
    void appendsFooterAfterABlankLine() {
        assertThat(FooterText.appendTo("Hello", "Follow me\nonX", Platform.LINKEDIN))
                .isEqualTo("Hello\n\nFollow me\nonX");
    }

    @Test
    void collapsesRunsOfBlankLinesToOne() {
        assertThat(FooterText.collapseBlankLines("line 1\n\n\n\n\nline 2\n\n\nline 3"))
                .isEqualTo("line 1\n\nline 2\n\nline 3");
        assertThat(FooterText.collapseBlankLines("a\r\n \r\n\t\r\n\r\nb")).isEqualTo("a\n\nb");
        assertThat(FooterText.collapseBlankLines("a\nb")).isEqualTo("a\nb");
        assertThat(FooterText.collapseBlankLines(null)).isEmpty();
    }

    @Test
    void appendedCaptionNeverHasMoreThanOneBlankLine() {
        assertThat(FooterText.appendTo("a\n\n\n\nb\n\n\n", "f1\n\n\n\nf2", Platform.LINKEDIN))
                .isEqualTo("a\n\nb\n\nf1\n\nf2");
    }

    @Test
    void leavesCaptionUntouchedWithoutFooter() {
        assertThat(FooterText.appendTo("Hello", "", Platform.WHATSAPP)).isEqualTo("Hello");
        assertThat(FooterText.appendTo(null, null, Platform.WHATSAPP)).isEmpty();
        assertThat(FooterText.appendTo("", "Footer", Platform.X)).isEqualTo("Footer");
    }
}
