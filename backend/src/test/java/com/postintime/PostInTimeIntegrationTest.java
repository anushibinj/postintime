package com.postintime;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.postintime.publishing.bulk.BulkPublishProcessor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class PostInTimeIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private BulkPublishProcessor bulkPublishProcessor;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private String user1Token;
    private String user2Token;
    private UUID techChannelId;
    private UUID gamingChannelId;

    @BeforeEach
    void setUp() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        user1Token = registerAndLogin("user1-" + suffix + "@example.com");
        user2Token = registerAndLogin("user2-" + suffix + "@example.com");
        techChannelId = createChannel(user1Token, "Tech", "tech-" + suffix);
        gamingChannelId = createChannel(user1Token, "Gaming", "gaming-" + suffix);
    }

    @Test
    void listPostsIsPaginated() throws Exception {
        for (int i = 1; i <= 5; i++) {
            createPost(user1Token, techChannelId, "Post " + i);
        }

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts")
                        .param("page", "0")
                        .param("size", "2")
                        .param("sort", "title,asc")
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(2))
                .andExpect(jsonPath("$.totalItems").value(5))
                .andExpect(jsonPath("$.totalPages").value(3))
                .andExpect(jsonPath("$.hasNext").value(true))
                .andExpect(jsonPath("$.hasPrevious").value(false))
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].title").value("Post 1"))
                .andExpect(jsonPath("$.items[1].title").value("Post 2"));

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts")
                        .param("page", "2")
                        .param("size", "2")
                        .param("sort", "title,asc")
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(2))
                .andExpect(jsonPath("$.hasNext").value(false))
                .andExpect(jsonPath("$.hasPrevious").value(true))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].title").value("Post 5"));

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts")
                        .param("page", "-1")
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts")
                        .param("size", "101")
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void channelIsolationAndCrossChannelTargeting() throws Exception {
        UUID techPostId = createPost(user1Token, techChannelId, "Tech Post");
        createPost(user1Token, gamingChannelId, "Gaming Post");

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts")
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalItems").value(1))
                .andExpect(jsonPath("$.items[0].title").value("Tech Post"));

        UUID gamingInstagramId = createSocialAccount(user1Token, gamingChannelId, "instagram", "Gaming IG");
        createSocialAccount(user1Token, techChannelId, "instagram", "Tech IG");

        String body = targetsBody(gamingInstagramId);

        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + techPostId + "/targets")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CROSS_CHANNEL_TARGET"));
    }

    @Test
    void publishingWorkflow() throws Exception {
        UUID postId = createPost(user1Token, techChannelId, "Sharding Post");
        UUID linkedinId = createSocialAccount(user1Token, techChannelId, "linkedin", "Tech LinkedIn");
        UUID instagramId = createSocialAccount(user1Token, techChannelId, "instagram", "Tech Instagram");

        String body = targetsBody(linkedinId, instagramId);

        MvcResult targetsResult = mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode targets = objectMapper.readTree(targetsResult.getResponse().getContentAsString());
        UUID targetId = UUID.fromString(targets.get(0).get("id").asText());

        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets/" + targetId + "/mark-published")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("published"));

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts/" + postId)
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.publicationSummary.published").value(1))
                .andExpect(jsonPath("$.targets.length()").value(2));

        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets/toggle")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"socialAccountId\":\"" + linkedinId + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("pending"));

        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets/toggle")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"socialAccountId\":\"" + linkedinId + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("published"));
    }

    @Test
    void unauthorizedAccessBlocked() throws Exception {
        mockMvc.perform(get("/api/v1/channels/" + techChannelId)
                        .header("Authorization", "Bearer " + user2Token))
                .andExpect(status().isNotFound());
    }

    @Test
    void deletePostRemovesTargets() throws Exception {
        UUID postId = createPost(user1Token, techChannelId, "Delete Me");
        UUID accountId = createSocialAccount(user1Token, techChannelId, "whatsapp", "Tech WA");
        String body = targetsBody(accountId);
        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated());

        mockMvc.perform(delete("/api/v1/channels/" + techChannelId + "/posts/" + postId)
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isNoContent());
    }

    @Test
    void disabledAccountCannotBeTargeted() throws Exception {
        UUID postId = createPost(user1Token, techChannelId, "Target Test");
        UUID accountId = createSocialAccount(user1Token, techChannelId, "youtube", "Tech YT");
        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/social-accounts/" + accountId + "/disable")
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isOk());

        String body = targetsBody(accountId);

        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DISABLED"));
    }

    @Test
    void apiTokenCanAuthenticateRefreshAndBeRevoked() throws Exception {
        MvcResult created = mockMvc.perform(post("/api/v1/api-tokens")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"CLI token\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.expiresAt").value(org.hamcrest.Matchers.nullValue()))
                .andReturn();

        JsonNode createdBody = objectMapper.readTree(created.getResponse().getContentAsString());
        String apiToken = createdBody.get("token").asText();
        UUID tokenId = UUID.fromString(createdBody.get("id").asText());

        mockMvc.perform(get("/api/v1/channels")
                        .header("Authorization", "Bearer " + apiToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));

        mockMvc.perform(get("/api/v1/api-tokens")
                        .header("Authorization", "Bearer " + user2Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isEmpty());

        MvcResult refreshed = mockMvc.perform(post("/api/v1/api-tokens/" + tokenId + "/refresh")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andReturn();
        String refreshedToken = objectMapper.readTree(refreshed.getResponse().getContentAsString())
                .get("token").asText();

        mockMvc.perform(get("/api/v1/channels")
                        .header("Authorization", "Bearer " + apiToken))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/v1/channels")
                        .header("Authorization", "Bearer " + refreshedToken))
                .andExpect(status().isOk());

        mockMvc.perform(delete("/api/v1/api-tokens/" + tokenId)
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/v1/channels")
                        .header("Authorization", "Bearer " + refreshedToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void publicListChannelsRequiresApiTokenAndReturnsMetadata() throws Exception {
        String apiToken = createApiToken(user1Token, "Public list");

        mockMvc.perform(get("/api/v1/public/channels"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(get("/api/v1/public/channels")
                        .header("Origin", "https://www.postman.com")
                        .header("Authorization", "bearer " + apiToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));

        mockMvc.perform(get("/api/v1/public/channels")
                        .header("X-Api-Key", apiToken))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/public/channels")
                        .header("Authorization", "Bearer " + apiToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[?(@.name=='Tech')].slug").exists())
                .andExpect(jsonPath("$[?(@.name=='Tech')].id").exists())
                .andExpect(jsonPath("$[?(@.name=='Tech')].enabled").exists())
                .andExpect(jsonPath("$[?(@.name=='Tech')].postCount").exists())
                .andExpect(jsonPath("$[?(@.name=='Tech')].socialAccountCount").exists())
                .andExpect(jsonPath("$[?(@.name=='Tech')].createdAt").exists())
                .andExpect(jsonPath("$[?(@.name=='Tech')].updatedAt").exists());

        String user2ApiToken = createApiToken(user2Token, "User2 list");
        mockMvc.perform(get("/api/v1/public/channels")
                        .header("Authorization", "Bearer " + user2ApiToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void publicCreatePostRequiresApiTokenAndAcceptsJsonOrMedia() throws Exception {
        String apiToken = createApiToken(user1Token, "Public create");
        String user2ApiToken = createApiToken(user2Token, "Other user");

        mockMvc.perform(post("/api/v1/public/channels/" + techChannelId + "/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"No auth\",\"caption\":\"Nope\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/v1/public/channels/" + techChannelId + "/posts")
                        .header("Authorization", "Bearer " + user2ApiToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Wrong owner\",\"caption\":\"Nope\"}"))
                .andExpect(status().isNotFound());

        mockMvc.perform(post("/api/v1/public/channels/" + techChannelId + "/posts")
                        .header("X-Api-Key", apiToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Public JSON post\",\"caption\":\"From API\",\"status\":\"ready\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("Public JSON post"))
                .andExpect(jsonPath("$.caption").value("From API"))
                .andExpect(jsonPath("$.channelId").value(techChannelId.toString()))
                .andExpect(jsonPath("$.status").value("ready"))
                .andExpect(jsonPath("$.media").value(org.hamcrest.Matchers.nullValue()));

        byte[] png = java.util.Base64.getDecoder().decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");
        MockMultipartFile media = new MockMultipartFile(
                "media", "pixel.png", "image/png", png);

        mockMvc.perform(multipart("/api/v1/public/channels/" + techChannelId + "/posts")
                        .file(media)
                        .param("title", "Public media post")
                        .param("caption", "With image")
                        .header("Authorization", "Bearer " + apiToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("Public media post"))
                .andExpect(jsonPath("$.caption").value("With image"))
                .andExpect(jsonPath("$.media.originalFilename").value("pixel.png"))
                .andExpect(jsonPath("$.media.contentType").value("image/png"));

        mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts")
                        .header("Authorization", "Bearer " + user1Token)
                        .param("search", "Public"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalItems").value(2));
    }

    @Test
    void unsupportedContentTypeReturns415Not401() throws Exception {
        mockMvc.perform(post("/api/v1/media")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.status").value(415))
                .andExpect(jsonPath("$.code").value("CONTENT_TYPE_NOT_SUPPORTED"));

        String apiToken = createApiToken(user1Token, "Content type");
        mockMvc.perform(post("/api/v1/public/channels/" + techChannelId + "/posts")
                        .header("Authorization", "Bearer " + apiToken)
                        .contentType(MediaType.TEXT_PLAIN)
                        .content("not json"))
                .andExpect(status().isUnsupportedMediaType())
                        .andExpect(jsonPath("$.code").value("CONTENT_TYPE_NOT_SUPPORTED"));
    }

    @Test
    void publicApiOpenApiDocsAreAvailableWithoutAuth() throws Exception {
        mockMvc.perform(get("/v3/api-docs/public"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.paths['/api/v1/public/channels'].get").exists())
                .andExpect(jsonPath("$.paths['/api/v1/public/channels/{channelId}/posts'].post").exists())
                .andExpect(jsonPath("$.paths['/api/v1/channels']").doesNotExist());

        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isOk());
    }

    @Test
    void webhookAccountRequiresUrlAndPublishesViaMultipartPost() throws Exception {
        mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/social-accounts")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"platform\":\"x\",\"name\":\"Webhook\",\"postingMode\":\"webhook\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        java.util.concurrent.atomic.AtomicReference<String> received = new java.util.concurrent.atomic.AtomicReference<>();
        java.util.concurrent.atomic.AtomicReference<String> receivedContentType = new java.util.concurrent.atomic.AtomicReference<>();
        com.sun.net.httpserver.HttpServer server = com.sun.net.httpserver.HttpServer.create(
                new java.net.InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/hook", exchange -> {
            byte[] body = exchange.getRequestBody().readAllBytes();
            receivedContentType.set(exchange.getRequestHeaders().getFirst("Content-Type"));
            received.set(exchange.getRequestMethod() + " "
                    + "content-length=" + exchange.getRequestHeaders().getFirst("Content-Length") + " "
                    + exchange.getRequestHeaders().getFirst("Content-Type") + " "
                    + new String(body));
            exchange.sendResponseHeaders(200, -1);
            exchange.close();
        });
        server.start();
        try {
            String webhookUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/hook";
            MvcResult created = mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/social-accounts")
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"platform\":\"x\",\"name\":\"Webhook\",\"postingMode\":\"webhook\","
                                    + "\"webhookUrl\":\"" + webhookUrl + "\",\"webhookAuthType\":\"none\"}"))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.postingMode").value("webhook"))
                    .andExpect(jsonPath("$.webhookUrl").value(webhookUrl))
                    .andExpect(jsonPath("$.webhookHasPassword").value(false))
                    .andReturn();
            UUID accountId = UUID.fromString(objectMapper.readTree(created.getResponse().getContentAsString())
                    .get("id").asText());

            byte[] png = java.util.Base64.getDecoder().decode(
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");
            MvcResult mediaResult = mockMvc.perform(multipart("/api/v1/media")
                            .file(new MockMultipartFile("file", "banner.png", "image/png", png))
                            .header("Authorization", "Bearer " + user1Token))
                    .andExpect(status().isCreated())
                    .andReturn();
            String mediaId = objectMapper.readTree(mediaResult.getResponse().getContentAsString()).get("id").asText();

            MvcResult postResult = mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts")
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"title\":\"Webhook Post\",\"caption\":\"Some description\",\"mediaId\":\""
                                    + mediaId + "\",\"status\":\"ready\"}"))
                    .andExpect(status().isCreated())
                    .andReturn();
            UUID postId = UUID.fromString(objectMapper.readTree(postResult.getResponse().getContentAsString())
                    .get("id").asText());

            mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets/toggle")
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"socialAccountId\":\"" + accountId + "\"}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("published"));

            String receivedBody = received.get();
            assertThat(receivedContentType.get())
                    .matches("multipart/form-data; boundary=-{26}[0-9a-f]{32}");
            assertThat(receivedBody).contains("POST");
            assertThat(receivedBody).containsPattern("content-length=[1-9][0-9]*");
            assertThat(receivedBody).contains("multipart/form-data");
            assertThat(receivedBody).contains("boundary=");
            assertThat(receivedBody).contains("name=\"title\"");
            assertThat(receivedBody).contains("Webhook Post");
            assertThat(receivedBody).contains("name=\"caption\"");
            assertThat(receivedBody).contains("Some description");
            assertThat(receivedBody).contains("name=\"media\"");
            assertThat(receivedBody).contains("banner.png");
            assertThat(receivedBody).contains("image/png");
            // Postman-style text parts must not include Content-Type (Spring's converter would add text/plain).
            int titleIndex = receivedBody.indexOf("name=\"title\"");
            int captionIndex = receivedBody.indexOf("name=\"caption\"");
            assertThat(receivedBody.substring(titleIndex, captionIndex)).doesNotContain("Content-Type:");
            assertThat(receivedBody.substring(captionIndex)).doesNotContain("Content-Type: text/plain");
        } finally {
            server.stop(0);
        }
    }

    @Test
    void mediaFileSupportsSizeQueryForThumbnails() throws Exception {
        byte[] png = java.util.Base64.getDecoder().decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC");
        MvcResult mediaResult = mockMvc.perform(multipart("/api/v1/media")
                        .file(new MockMultipartFile("file", "thumb-source.png", "image/png", png))
                        .header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isCreated())
                .andReturn();
        String url = objectMapper.readTree(mediaResult.getResponse().getContentAsString()).get("url").asText();
        String path = java.net.URI.create(url).getPath();

        mockMvc.perform(get(path).param("size", "8"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        MvcResult thumb = mockMvc.perform(get(path).param("size", "32"))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content()
                        .contentTypeCompatibleWith(MediaType.IMAGE_JPEG))
                .andReturn();

        byte[] thumbBytes = thumb.getResponse().getContentAsByteArray();
        assertThat(thumbBytes.length).isGreaterThan(0);
        java.awt.image.BufferedImage image = javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(thumbBytes));
        assertThat(image.getWidth()).isEqualTo(32);
        assertThat(image.getHeight()).isEqualTo(32);

        mockMvc.perform(get(path))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content()
                        .contentTypeCompatibleWith(MediaType.IMAGE_PNG));
    }

    @Test
    void webhookPublishFailureReturnsDetailedError() throws Exception {
        com.sun.net.httpserver.HttpServer server = com.sun.net.httpserver.HttpServer.create(
                new java.net.InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/hook", exchange -> {
            byte[] response = "n8n exploded".getBytes();
            exchange.sendResponseHeaders(500, response.length);
            exchange.getResponseBody().write(response);
            exchange.close();
        });
        server.start();
        try {
            String webhookUrl = "http://127.0.0.1:" + server.getAddress().getPort() + "/hook";
            MvcResult created = mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/social-accounts")
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"platform\":\"linkedin\",\"name\":\"Failing webhook\",\"postingMode\":\"webhook\","
                                    + "\"webhookUrl\":\"" + webhookUrl + "\"}"))
                    .andExpect(status().isCreated())
                    .andReturn();
            UUID accountId = UUID.fromString(objectMapper.readTree(created.getResponse().getContentAsString())
                    .get("id").asText());
            UUID postId = createPost(user1Token, techChannelId, "Will Fail");

            mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/posts/" + postId + "/targets/toggle")
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"socialAccountId\":\"" + accountId + "\"}"))
                    .andExpect(status().isUnprocessableEntity())
                    .andExpect(jsonPath("$.code").value("PUBLISH_FAILED"))
                    .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("n8n exploded")));
        } finally {
            server.stop(0);
        }
    }

    @Test
    void bulkPublishValidatesRequest() throws Exception {
        UUID postId = createPost(user1Token, techChannelId, "Bulk Validation");
        String base = "/api/v1/channels/" + techChannelId + "/bulk-publish-jobs";

        mockMvc.perform(post(base)
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bulkBody(5, postId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("NO_WEBHOOK_ACCOUNTS"));

        createWebhookAccount(techChannelId, "Bulk hook", "http://127.0.0.1:1/never-called");
        for (int interval : new int[]{0, 7, 35}) {
            mockMvc.perform(post(base)
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(bulkBody(interval, postId)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
        }

        UUID gamingPostId = createPost(user1Token, gamingChannelId, "Other channel");
        mockMvc.perform(post(base)
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bulkBody(5, postId, gamingPostId)))
                .andExpect(status().isNotFound());

        mockMvc.perform(post(base)
                        .header("Authorization", "Bearer " + user2Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bulkBody(5, postId)))
                .andExpect(status().isNotFound());
    }

    @Test
    void bulkPublishPostsOneAtATimeAndMovesOnAfterFailures() throws Exception {
        java.util.List<String> received = java.util.Collections.synchronizedList(new java.util.ArrayList<>());
        java.util.concurrent.atomic.AtomicInteger inFlight = new java.util.concurrent.atomic.AtomicInteger();
        java.util.concurrent.atomic.AtomicInteger maxInFlight = new java.util.concurrent.atomic.AtomicInteger();
        com.sun.net.httpserver.HttpServer server = com.sun.net.httpserver.HttpServer.create(
                new java.net.InetSocketAddress("127.0.0.1", 0), 0);
        server.setExecutor(java.util.concurrent.Executors.newFixedThreadPool(4));
        server.createContext("/", exchange -> {
            maxInFlight.accumulateAndGet(inFlight.incrementAndGet(), Math::max);
            String body = new String(exchange.getRequestBody().readAllBytes());
            String path = exchange.getRequestURI().getPath();
            received.add(path + " " + (body.contains("Bulk First") ? "first" : "second"));
            int code = path.equals("/fail") ? 500 : 200;
            exchange.sendResponseHeaders(code, -1);
            exchange.close();
            inFlight.decrementAndGet();
        });
        server.start();
        try {
            String root = "http://127.0.0.1:" + server.getAddress().getPort();
            createWebhookAccount(techChannelId, "A failing hook", root + "/fail");
            UUID okAccountId = createWebhookAccount(techChannelId, "B working hook", root + "/ok");
            UUID first = createPost(user1Token, techChannelId, "Bulk First");
            UUID second = createPost(user1Token, techChannelId, "Bulk Second");

            MvcResult created = mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/bulk-publish-jobs")
                            .header("Authorization", "Bearer " + user1Token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(bulkBody(10, first, second, first)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.status").value("running"))
                    .andExpect(jsonPath("$.intervalMinutes").value(10))
                    .andExpect(jsonPath("$.totalItems").value(2))
                    .andExpect(jsonPath("$.items[0].postTitle").value("Bulk First"))
                    .andExpect(jsonPath("$.items[1].postTitle").value("Bulk Second"))
                    .andReturn();
            UUID jobId = UUID.fromString(objectMapper.readTree(created.getResponse().getContentAsString())
                    .get("id").asText());
            String jobUrl = "/api/v1/channels/" + techChannelId + "/bulk-publish-jobs/" + jobId;

            assertThat(bulkPublishProcessor.processNextDueJob()).isTrue();
            // The second post waits for the interval.
            assertThat(bulkPublishProcessor.processNextDueJob()).isFalse();
            assertThat(received).containsExactly("/fail first", "/ok first");

            mockMvc.perform(get(jobUrl).header("Authorization", "Bearer " + user1Token))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("running"))
                    .andExpect(jsonPath("$.processedItems").value(1))
                    .andExpect(jsonPath("$.failedItems").value(1))
                    .andExpect(jsonPath("$.items[0].status").value("partial"))
                    .andExpect(jsonPath("$.items[0].errorMessage")
                            .value(org.hamcrest.Matchers.containsString("A failing hook")))
                    .andExpect(jsonPath("$.items[1].status").value("pending"));

            jdbcTemplate.update("UPDATE bulk_publish_jobs SET next_run_at = now() WHERE id = ?", jobId);
            assertThat(bulkPublishProcessor.processNextDueJob()).isTrue();
            assertThat(received).containsExactly("/fail first", "/ok first", "/fail second", "/ok second");
            assertThat(maxInFlight.get()).isEqualTo(1);

            mockMvc.perform(get(jobUrl).header("Authorization", "Bearer " + user1Token))
                    .andExpect(jsonPath("$.status").value("completed"))
                    .andExpect(jsonPath("$.nextRunAt").doesNotExist())
                    .andExpect(jsonPath("$.processedItems").value(2));

            mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/posts/" + second + "/targets")
                            .header("Authorization", "Bearer " + user1Token))
                    .andExpect(jsonPath("$.length()").value(2))
                    .andExpect(jsonPath("$[?(@.socialAccount.id == '" + okAccountId + "')].status")
                            .value(org.hamcrest.Matchers.contains("published")))
                    .andExpect(jsonPath("$[?(@.socialAccount.name == 'A failing hook')].status")
                            .value(org.hamcrest.Matchers.contains("failed")));

            mockMvc.perform(get("/api/v1/channels/" + techChannelId + "/bulk-publish-jobs")
                            .header("Authorization", "Bearer " + user1Token))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$[0].id").value(jobId.toString()));
        } finally {
            server.stop(0);
        }
    }

    @Test
    void bulkPublishJobCanBeCancelled() throws Exception {
        createWebhookAccount(techChannelId, "Cancel hook", "http://127.0.0.1:1/never-called");
        UUID postId = createPost(user1Token, techChannelId, "Cancel Me");
        MvcResult created = mockMvc.perform(post("/api/v1/channels/" + techChannelId + "/bulk-publish-jobs")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"postIds\":[\"" + postId + "\"]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.intervalMinutes").value(5))
                .andReturn();
        UUID jobId = UUID.fromString(objectMapper.readTree(created.getResponse().getContentAsString())
                .get("id").asText());
        String cancelUrl = "/api/v1/channels/" + techChannelId + "/bulk-publish-jobs/" + jobId + "/cancel";

        mockMvc.perform(post(cancelUrl).header("Authorization", "Bearer " + user2Token))
                .andExpect(status().isNotFound());
        mockMvc.perform(post(cancelUrl).header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("cancelled"))
                .andExpect(jsonPath("$.items[0].status").value("cancelled"));
        mockMvc.perform(post(cancelUrl).header("Authorization", "Bearer " + user1Token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_STATE"));
    }

    private String bulkBody(int intervalMinutes, UUID... postIds) {
        var node = objectMapper.createObjectNode();
        node.put("intervalMinutes", intervalMinutes);
        var array = node.putArray("postIds");
        for (UUID id : postIds) {
            array.add(id.toString());
        }
        return node.toString();
    }

    private UUID createWebhookAccount(UUID channelId, String name, String webhookUrl) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/channels/" + channelId + "/social-accounts")
                        .header("Authorization", "Bearer " + user1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"platform\":\"linkedin\",\"name\":\"" + name + "\",\"postingMode\":\"webhook\","
                                + "\"webhookUrl\":\"" + webhookUrl + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(objectMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private String targetsBody(UUID... accountIds) throws Exception {
        var node = objectMapper.createObjectNode();
        var array = node.putArray("socialAccountIds");
        for (UUID id : accountIds) {
            array.add(id.toString());
        }
        return node.toString();
    }

    private String registerAndLogin(String email) throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"))
                .andExpect(status().isCreated());
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"password123\"}"))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("token").asText();
    }

    private UUID createChannel(String token, String name, String slug) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/channels")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"" + name + "\",\"slug\":\"" + slug + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(objectMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private UUID createPost(String token, UUID channelId, String title) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/channels/" + channelId + "/posts")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"" + title + "\",\"status\":\"ready\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(objectMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private String createApiToken(String sessionToken, String name) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/api-tokens")
                        .header("Authorization", "Bearer " + sessionToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"" + name + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("token").asText();
    }

    private UUID createSocialAccount(String token, UUID channelId, String platform, String name) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/channels/" + channelId + "/social-accounts")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"platform\":\"" + platform + "\",\"name\":\"" + name + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(objectMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }
}
