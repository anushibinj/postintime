package com.postintime.channel;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ChannelAutopublishTest {

    private Channel channel(boolean enabled, int threshold) {
        Channel channel = new Channel();
        channel.setAutopublishEnabled(enabled);
        channel.setAutopublishThreshold(threshold);
        return channel;
    }

    @Test
    void acceptsScoresAtOrAboveTheThreshold() {
        Channel channel = channel(true, 80);
        assertThat(channel.accepts(80)).isTrue();
        assertThat(channel.accepts(100)).isTrue();
        assertThat(channel.accepts(79)).isFalse();
        assertThat(channel.accepts(0)).isFalse();
    }

    @Test
    void neverAcceptsWhenAutopublishIsOff() {
        assertThat(channel(false, 0).accepts(100)).isFalse();
    }

    @Test
    void neverAcceptsAPostWithoutAScore() {
        assertThat(channel(true, 0).accepts(null)).isFalse();
    }

    @Test
    void newChannelsStartWithAutopublishOffAndThresholdEighty() {
        Channel channel = new Channel();
        assertThat(channel.isAutopublishEnabled()).isFalse();
        assertThat(channel.getAutopublishThreshold()).isEqualTo(80);
    }
}
