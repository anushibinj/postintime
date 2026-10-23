package com.postintime.publishing.bulk;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/channels/{channelId}/bulk-publish-jobs")
public class BulkPublishController {

    private final BulkPublishService bulkPublishService;

    public BulkPublishController(BulkPublishService bulkPublishService) {
        this.bulkPublishService = bulkPublishService;
    }

    @GetMapping
    public List<BulkPublishJobResponse> listJobs(@PathVariable UUID channelId) {
        return bulkPublishService.listRecentJobs(channelId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BulkPublishJobResponse createJob(@PathVariable UUID channelId,
                                            @Valid @RequestBody CreateBulkPublishRequest request) {
        return bulkPublishService.createJob(channelId, request);
    }

    @GetMapping("/{jobId}")
    public BulkPublishJobResponse getJob(@PathVariable UUID channelId, @PathVariable UUID jobId) {
        return bulkPublishService.getJob(channelId, jobId);
    }

    @PostMapping("/{jobId}/cancel")
    public BulkPublishJobResponse cancelJob(@PathVariable UUID channelId, @PathVariable UUID jobId) {
        return bulkPublishService.cancelJob(channelId, jobId);
    }
}
