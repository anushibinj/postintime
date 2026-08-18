package com.postintime.publicapi;

import com.postintime.channel.ChannelResponse;
import com.postintime.channel.ChannelService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/public/channels")
public class PublicChannelController {

    private final ChannelService channelService;

    public PublicChannelController(ChannelService channelService) {
        this.channelService = channelService;
    }

    @GetMapping
    public List<ChannelResponse> listChannels() {
        return channelService.listChannels();
    }
}
