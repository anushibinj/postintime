package com.postintime.publishing.bulk;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Polls the bulk publishing queues for due posts. Runs on Spring's single scheduler thread, so
 * posts are always published one at a time, never in parallel.
 */
@Component
public class BulkPublishScheduler {

    private static final Logger log = LoggerFactory.getLogger(BulkPublishScheduler.class);

    /** Upper bound per tick so one poll cannot run forever. */
    private static final int MAX_ITEMS_PER_TICK = 50;

    private final BulkPublishProcessor processor;

    public BulkPublishScheduler(BulkPublishProcessor processor) {
        this.processor = processor;
    }

    @Scheduled(fixedDelayString = "${app.bulk-publish.poll-interval-ms:10000}")
    public void publishDueItems() {
        try {
            processor.failStalledItems();
        } catch (Exception ex) {
            log.error("Bulk publish stall check failed", ex);
        }
        for (int i = 0; i < MAX_ITEMS_PER_TICK; i++) {
            try {
                if (!processor.processNextDueItem()) {
                    return;
                }
            } catch (Exception ex) {
                log.error("Bulk publish poll failed", ex);
                return;
            }
        }
    }
}
