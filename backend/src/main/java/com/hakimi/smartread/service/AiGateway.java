package com.hakimi.smartread.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.LinkedHashMap;
import java.util.Map;

@Component
public class AiGateway {
    private final RestClient client;

    public AiGateway(RestClient.Builder builder, @Value("${ai.service.base-url}") String baseUrl) {
        this.client = builder.baseUrl(baseUrl).build();
    }

    public Map<String, Object> recommend(Map<String, Object> payload) {
        return post("/internal/rag/recommend", payload);
    }

    public Map<String, Object> chat(Map<String, Object> payload) {
        return post("/internal/rag/chat", payload);
    }

    public Map<String, Object> commerceSearch(Map<String, Object> payload) {
        return post("/internal/tools/commerce-search", payload);
    }

    private Map<String, Object> post(String path, Map<String, Object> payload) {
        try {
            Map<String, Object> requestBody = payload == null ? Map.of() : new LinkedHashMap<>(payload);
            Map<String, Object> body = client.post()
                    .uri(path)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(requestBody)
                    .retrieve()
                    .body(new ParameterizedTypeReference<>() {
                    });
            if (body == null) {
                throw SmartReadException.upstream("AI 服务返回为空");
            }
            return body;
        } catch (RestClientException ex) {
            throw SmartReadException.upstream("AI 服务调用失败：" + ex.getMessage());
        }
    }
}
