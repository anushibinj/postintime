package com.postintime.publicapi;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI postInTimePublicOpenApi() {
        SecurityScheme bearer = new SecurityScheme()
                .type(SecurityScheme.Type.HTTP)
                .scheme("bearer")
                .bearerFormat("API token")
                .description("Personal API token from Settings. Send the full pit_… secret.");
        SecurityScheme apiKey = new SecurityScheme()
                .type(SecurityScheme.Type.APIKEY)
                .in(SecurityScheme.In.HEADER)
                .name("X-Api-Key")
                .description("Same pit_… token as an alternative to Authorization: Bearer.");
        return new OpenAPI()
                .info(new Info()
                        .title("PostInTime Public API")
                        .version("v1")
                        .description("""
                                Authenticated with a personal API token (`pit_…`). \
                                Use Authorize in Swagger UI, or send `Authorization: Bearer <token>` / `X-Api-Key`. \
                                Tokens are created in the PostInTime Settings page."""))
                .components(new Components()
                        .addSecuritySchemes("bearerAuth", bearer)
                        .addSecuritySchemes("apiKeyAuth", apiKey))
                .addSecurityItem(new SecurityRequirement().addList("bearerAuth"))
                .addSecurityItem(new SecurityRequirement().addList("apiKeyAuth"));
    }

    @Bean
    public GroupedOpenApi publicApis() {
        return GroupedOpenApi.builder()
                .group("public")
                .displayName("Public APIs")
                .pathsToMatch("/api/v1/public/**")
                .build();
    }
}
