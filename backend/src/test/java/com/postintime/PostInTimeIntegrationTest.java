package com.postintime;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
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
                .andExpect(jsonPath("$.publicationSummary.published").value(1));
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
