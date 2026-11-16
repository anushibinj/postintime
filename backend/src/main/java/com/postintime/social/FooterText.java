package com.postintime.social;

import java.util.Map;

/**
 * Footer text is stored once in a canonical form (LF newlines, trimmed) and converted to the newline
 * sequence a platform expects only when a caption is published.
 *
 * Every platform postintime supports (WhatsApp, LinkedIn, Instagram, Facebook, X, Threads, YouTube) takes
 * a plain {@code \n} line break in post text: LinkedIn's and Meta's APIs and WhatsApp markup all use LF,
 * and a CRLF would render as an extra blank line or a stray character on several of them. The per-platform
 * map exists so a platform that does need something else can be added in one place.
 */
public final class FooterText {

    private static final String LF = "\n";
    private static final Map<Platform, String> NEWLINES = Map.of();

    private FooterText() {
    }

    public static String newlineFor(Platform platform) {
        return NEWLINES.getOrDefault(platform, LF);
    }

    /** Canonical stored form: never null, CRLF/CR collapsed to LF, surrounding blank space removed. */
    public static String normalize(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\r\n", LF).replace('\r', '\n').strip();
    }

    /**
     * Collapses CRLF/CR to LF, drops trailing spaces on each line and reduces any run of blank lines to a
     * single blank line, so a post never has more than one empty line between paragraphs.
     */
    public static String collapseBlankLines(String value) {
        if (value == null) {
            return "";
        }
        return value.replace("\r\n", LF).replace('\r', '\n')
                .replaceAll("[ \\t\\u00A0]+\\n", LF)
                .replaceAll("\\n{3,}", "\n\n");
    }

    /** The footer using the newline convention of {@code platform}. */
    public static String forPlatform(String footer, Platform platform) {
        String canonical = normalize(footer);
        String newline = newlineFor(platform);
        return LF.equals(newline) ? canonical : canonical.replace(LF, newline);
    }

    /** The caption followed by a blank line and the footer; the caption alone when there is no footer. */
    public static String appendTo(String caption, String footer, Platform platform) {
        String base = collapseBlankLines(caption).stripTrailing();
        String formatted = collapseBlankLines(forPlatform(footer, platform));
        if (formatted.isEmpty()) {
            return base;
        }
        String newline = newlineFor(platform);
        if (base.isBlank()) {
            return formatted;
        }
        return base + newline + newline + formatted;
    }
}
