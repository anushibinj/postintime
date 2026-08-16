package com.postintime.channel;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/channels")
public class ChannelController {

    private final ChannelService channelService;

    public ChannelController(ChannelService channelService) {
        this.channelService = channelService;
    }

    @GetMapping
    public List<ChannelResponse> listChannels() {
        return channelService.listChannels();
    }

    @GetMapping("/{channelId}")
    public ChannelResponse getChannel(@PathVariable UUID channelId) {
        return channelService.getChannel(channelId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ChannelResponse createChannel(@Valid @RequestBody CreateChannelRequest request) {
        return channelService.createChannel(request);
    }

    @PatchMapping("/{channelId}")
    public ChannelResponse updateChannel(@PathVariable UUID channelId,
                                         @Valid @RequestBody UpdateChannelRequest request) {
        return channelService.updateChannel(channelId, request);
    }

    @DeleteMapping("/{channelId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteChannel(@PathVariable UUID channelId) {
        channelService.deleteChannel(channelId);
    }
}
