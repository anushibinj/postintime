package com.postintime.publicapi;

import com.postintime.channel.ChannelResponse;
import com.postintime.channel.ChannelService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/public/channels")
@Tag(name = "Public channels", description = "List channels for the API token owner")
public class PublicChannelController {

    private final ChannelService channelService;

    public PublicChannelController(ChannelService channelService) {
        this.channelService = channelService;
    }

    @GetMapping
    @Operation(
            summary = "List channels",
            description = "Returns all channels owned by the user who created the API token, including metadata."
    )
    @ApiResponse(
            responseCode = "200",
            description = "Channels for the authenticated user",
            content = @Content(array = @ArraySchema(schema = @Schema(implementation = ChannelResponse.class)))
    )
    @ApiResponse(responseCode = "401", description = "Missing or invalid API token", content = @Content)
    public List<ChannelResponse> listChannels() {
        return channelService.listChannels();
    }
}
