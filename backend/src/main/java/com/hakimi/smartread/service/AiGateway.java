package com.hakimi.smartread.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.function.Consumer;

@Component
public class AiGateway {
    private final RestClient client;
    private final ObjectMapper objectMapper;
    private final HttpClient streamClient;
    private final String baseUrl;

    public AiGateway(RestClient.Builder builder, @Value("${ai.service.base-url}") String baseUrl,
                     ObjectMapper objectMapper) {
        this.baseUrl = trimTrailingSlash(baseUrl);
        this.client = builder.baseUrl(baseUrl).build();
        this.objectMapper = objectMapper;
        this.streamClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
    }

    public Map<String, Object> recommend(Map<String, Object> payload) {
        return post("/internal/rag/recommend", payload);
    }

    public Map<String, Object> chat(Map<String, Object> payload) {
        return post("/internal/rag/chat", payload);
    }

    public void recommendStream(Map<String, Object> payload, OutputStream output,
                                Consumer<Map<String, Object>> onFinal) {
        stream("/internal/rag/recommend/stream", payload, output, onFinal);
    }

    public void chatStream(Map<String, Object> payload, OutputStream output,
                           Consumer<Map<String, Object>> onFinal) {
        stream("/internal/rag/chat/stream", payload, output, onFinal);
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

    private void stream(String path, Map<String, Object> payload, OutputStream output,
                        Consumer<Map<String, Object>> onFinal) {
        Map<String, Object> requestBody = payload == null ? Map.of() : new LinkedHashMap<>(payload);
        try {
            HttpRequest request = HttpRequest.newBuilder(streamUri(path))
                    .timeout(Duration.ofSeconds(90))
                    .header("Content-Type", MediaType.APPLICATION_JSON_VALUE)
                    .header("Accept", "application/x-ndjson")
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(requestBody),
                            StandardCharsets.UTF_8))
                    .build();
            HttpResponse<InputStream> response = streamClient.send(request, HttpResponse.BodyHandlers.ofInputStream());
            if (response.statusCode() >= 400) {
                String body = new String(response.body().readAllBytes(), StandardCharsets.UTF_8);
                throw SmartReadException.upstream("AI 流式服务返回 " + response.statusCode() + "：" + body);
            }
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(response.body(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    if (line.isBlank()) {
                        continue;
                    }
                    writeNdjsonLine(output, line);
                    Map<String, Object> finalData = finalData(line);
                    if (finalData != null && onFinal != null) {
                        onFinal.accept(finalData);
                    }
                }
            }
        } catch (SmartReadException ex) {
            writeStreamError(output, ex.getMessage());
        } catch (IOException ex) {
            writeStreamError(output, "AI 流式传输失败：" + ex.getMessage());
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            writeStreamError(output, "AI 流式传输被中断");
        }
    }

    private void writeNdjsonLine(OutputStream output, String line) throws IOException {
        output.write(line.getBytes(StandardCharsets.UTF_8));
        output.write('\n');
        output.flush();
    }

    private void writeStreamError(OutputStream output, String message) {
        try {
            Map<String, Object> event = new LinkedHashMap<>();
            event.put("type", "error");
            event.put("code", 502);
            event.put("message", message == null || message.isBlank() ? "AI 流式响应失败，请稍后重试。" : message);
            writeNdjsonLine(output, objectMapper.writeValueAsString(event));
        } catch (IOException ignored) {
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> finalData(String line) {
        try {
            Map<String, Object> event = objectMapper.readValue(line, new TypeReference<>() {
            });
            String type = String.valueOf(event.getOrDefault("type", ""));
            Object data = event.get("data");
            if ("final".equals(type) && data instanceof Map<?, ?> map) {
                return new LinkedHashMap<>((Map<String, Object>) map);
            }
        } catch (JsonProcessingException ignored) {
        }
        return null;
    }

    private URI streamUri(String path) {
        return URI.create(baseUrl + (path.startsWith("/") ? path : "/" + path));
    }

    private static String trimTrailingSlash(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        return value.endsWith("/") ? value.substring(0, value.length() - 1) : value;
    }
}
