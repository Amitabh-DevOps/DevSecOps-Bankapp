package com.example.bankapp.service;

import com.example.bankapp.model.Account;
import com.example.bankapp.model.Transaction;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

import java.util.Collections;
import java.util.List;
import java.util.Map;

@Service
public class ChatService {

    @Value("${ollama.url}")
    private String ollamaUrl;

    @Value("${ollama.model}")
    private String model;

    @Value("${ai.provider:ollama}")
    private String aiProvider;

    @Value("${ai.fallback-to-ollama:true}")
    private boolean fallbackToOllama;

    @Value("${gemini.api.url:https://generativelanguage.googleapis.com/v1beta/models}")
    private String geminiApiUrl;

    @Value("${gemini.model:gemini-1.5-flash}")
    private String geminiModel;

    @Value("${gemini.api.key:}")
    private String geminiApiKey;

    @Value("${ollama.timeout.connect-ms:3000}")
    private int connectTimeoutMs;

    @Value("${ollama.timeout.read-ms:30000}")
    private int readTimeoutMs;

    private final RestTemplateBuilder restTemplateBuilder;
    private final AccountService accountService;

    public ChatService(AccountService accountService, RestTemplateBuilder restTemplateBuilder) {
        this.accountService = accountService;
        this.restTemplateBuilder = restTemplateBuilder;
    }

    public String chat(Account account, String userMessage) {
        List<Transaction> recent = accountService.getTransactionHistory(account);
        String context = buildContext(account, recent);

        RestTemplate restTemplate = restTemplateBuilder
            .setConnectTimeout(Duration.ofMillis(connectTimeoutMs))
            .setReadTimeout(Duration.ofMillis(readTimeoutMs))
            .build();

        try {
            if ("gemini".equalsIgnoreCase(aiProvider)) {
                return askGemini(restTemplate, context, userMessage);
            }
            return askOllama(restTemplate, context, userMessage);
        } catch (ResourceAccessException e) {
            return "AI assistant is taking longer than expected. Please try again in a few seconds.";
        } catch (Exception e) {
            if ("gemini".equalsIgnoreCase(aiProvider) && fallbackToOllama) {
                try {
                    return askOllama(restTemplate, context, userMessage);
                } catch (Exception ignored) {
                    return "AI assistant is unavailable. Please try again shortly.";
                }
            }
            return "AI assistant is unavailable. Please try again shortly.";
        }
    }

    private String askOllama(RestTemplate restTemplate, String context, String userMessage) {
        Map<String, Object> request = Map.of(
            "model", model,
            "messages", List.of(
                Map.of("role", "system", "content", context),
                Map.of("role", "user", "content", userMessage)
            ),
            "stream", false
        );

        Map<String, Object> response = restTemplate.postForObject(
            ollamaUrl + "/api/chat", request, Map.class
        );
        if (response != null && response.containsKey("message")) {
            Map<String, String> message = (Map<String, String>) response.get("message");
            return message.getOrDefault("content", "Sorry, I couldn't process that.");
        }
        return "Sorry, I couldn't process that.";
    }

    private String askGemini(RestTemplate restTemplate, String context, String userMessage) {
        if (geminiApiKey == null || geminiApiKey.isBlank()) {
            throw new IllegalStateException("GEMINI_API_KEY is missing");
        }

        Map<String, Object> request = Map.of(
            "system_instruction", Map.of(
                "parts", List.of(Map.of("text", context))
            ),
            "contents", List.of(
                Map.of(
                    "role", "user",
                    "parts", List.of(Map.of("text", userMessage))
                )
            ),
            "generationConfig", Map.of(
                "temperature", 0.2,
                "maxOutputTokens", 200
            )
        );

        String endpoint = geminiApiUrl + "/" + geminiModel + ":generateContent?key=" + geminiApiKey;
        Map<String, Object> response = restTemplate.postForObject(endpoint, request, Map.class);

        if (response == null) {
            return "Sorry, I couldn't process that.";
        }

        List<Map<String, Object>> candidates = (List<Map<String, Object>>) response.getOrDefault("candidates", Collections.emptyList());
        if (candidates.isEmpty()) {
            return "Sorry, I couldn't process that.";
        }

        Map<String, Object> content = (Map<String, Object>) candidates.get(0).getOrDefault("content", Collections.emptyMap());
        List<Map<String, Object>> parts = (List<Map<String, Object>>) content.getOrDefault("parts", Collections.emptyList());
        if (parts.isEmpty()) {
            return "Sorry, I couldn't process that.";
        }

        Object text = parts.get(0).get("text");
        return text == null ? "Sorry, I couldn't process that." : text.toString();
    }

    private String buildContext(Account account, List<Transaction> transactions) {
        StringBuilder sb = new StringBuilder();
        sb.append("You are a helpful banking assistant for BankApp. ");
        sb.append("Keep answers short and friendly (2-3 sentences max). ");
        sb.append("\n\nCustomer details:");
        sb.append("\n- Username: ").append(account.getUsername());
        sb.append("\n- Balance: $").append(account.getBalance());
        sb.append("\n- Account ID: ").append(account.getId());

        if (!transactions.isEmpty()) {
            sb.append("\n\nRecent transactions:");
            int limit = Math.min(transactions.size(), 5);
            for (int i = 0; i < limit; i++) {
                Transaction t = transactions.get(i);
                sb.append("\n- ").append(t.getType())
                  .append(": $").append(t.getAmount())
                  .append(" on ").append(t.getTimestamp().toLocalDate());
            }
        } else {
            sb.append("\n\nNo transactions yet.");
        }

        return sb.toString();
    }
}
