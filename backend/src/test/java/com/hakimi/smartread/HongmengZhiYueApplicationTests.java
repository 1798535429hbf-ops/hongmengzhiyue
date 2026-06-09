package com.hakimi.smartread;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.controller.AiController;
import com.hakimi.smartread.controller.BookController;
import com.hakimi.smartread.controller.ImportController;
import com.hakimi.smartread.controller.ReaderInteractionController;
import com.hakimi.smartread.controller.UserController;
import com.hakimi.smartread.repository.SmartReadRepository;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;

import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

class HongmengZhiYueApplicationTests {

	@Test
	void apiResponseUsesPrdEnvelope() {
		ApiResponse<String> response = ApiResponse.ok("done");
		Assertions.assertEquals(0, response.code());
		Assertions.assertEquals("ok", response.message());
		Assertions.assertEquals("done", response.data());
	}

	@Test
	void schemaDefinesReadableChapterTablesAndProgressFields() throws Exception {
		String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);

		Assertions.assertTrue(schema.contains("source_type"));
		Assertions.assertTrue(schema.contains("readable"));
		Assertions.assertTrue(schema.contains("import_status"));
		Assertions.assertTrue(schema.contains("source_note"));
		Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS book_chapter"));
		Assertions.assertTrue(schema.contains("chapter_id VARCHAR(64) NOT NULL"));
		Assertions.assertTrue(schema.contains("paragraphs_json JSON"));
		Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS book_import_record"));
		Assertions.assertTrue(schema.contains("scroll_offset INT NOT NULL DEFAULT 0"));
	}

	@Test
	void readingPlanSchemaSupportsPerBookTimeTargets() throws Exception {
		String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(schema.contains("daily_minutes_target INT NOT NULL DEFAULT 30"));
		Assertions.assertTrue(schema.contains("weekly_minutes_target INT NOT NULL DEFAULT 210"));
		Assertions.assertTrue(repository.contains("daily_minutes_target AS dailyMinutesTarget"));
		Assertions.assertTrue(repository.contains("weekly_minutes_target AS weeklyMinutesTarget"));
		Assertions.assertTrue(repository.contains("daily_minutes_target = COALESCE"));
		Assertions.assertTrue(service.contains("Payloads.integer(payload, \"daily_minutes_target\", 30)"));
		Assertions.assertTrue(service.contains("optionalInteger(payload, \"weekly_minutes_target\")"));
	}

	@Test
	void readerInteractionSchemaAndEndpointsStayAligned() throws Exception {
		String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS reader_highlight"));
		Assertions.assertTrue(schema.contains("start_offset INT NOT NULL DEFAULT 0"));
		Assertions.assertTrue(schema.contains("end_offset INT NOT NULL DEFAULT 0"));
		Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS reader_comment"));
		Assertions.assertTrue(repository.contains("start_offset AS startOffset"));
		Assertions.assertTrue(repository.contains("end_offset AS endOffset"));
		Assertions.assertTrue(service.contains("Payloads.integer(payload, \"start_offset\", 0)"));
		Assertions.assertTrue(service.contains("Payloads.integer(payload, \"end_offset\", selectedText.length())"));

		Method highlights = ReaderInteractionController.class.getMethod("highlights", long.class, long.class, String.class);
		Method createHighlight = ReaderInteractionController.class.getMethod("createHighlight", Map.class);
		Method comments = ReaderInteractionController.class.getMethod("comments", long.class, long.class, String.class, int.class);
		Method createComment = ReaderInteractionController.class.getMethod("createComment", Map.class);
		Assertions.assertArrayEquals(new String[]{"/highlights"}, highlights.getAnnotation(GetMapping.class).value());
		Assertions.assertArrayEquals(new String[]{"/highlights"}, createHighlight.getAnnotation(PostMapping.class).value());
		Assertions.assertArrayEquals(new String[]{"/comments"}, comments.getAnnotation(GetMapping.class).value());
		Assertions.assertArrayEquals(new String[]{"/comments"}, createComment.getAnnotation(PostMapping.class).value());
	}

	@Test
	void chatEnrichesPayloadWithBookSources() throws Exception {
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);
		Assertions.assertTrue(service.contains("enriched.put(\"sources\", repository.findChunks"));
	}

	@Test
	void chatForwardsReaderContextAndWarmCompanionOptions() throws Exception {
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(service.contains("Payloads.text(payload, \"chapter_id\""));
		Assertions.assertTrue(service.contains("Payloads.text(payload, \"paragraph\""));
		Assertions.assertTrue(service.contains("enriched.putIfAbsent(\"tone\", \"warm_companion\")"));
		Assertions.assertTrue(service.contains("enriched.putIfAbsent(\"allow_external_search\", true)"));
		Assertions.assertTrue(service.contains("enriched.put(\"chapter\", repository.getReadingContent"));
		Assertions.assertTrue(service.contains("String retrievalQuery = paragraph.isBlank() ? question : question + \" \" + paragraph"));
	}

	@Test
	void aiStreamEndpointsStayNdjsonAndEmitReadableErrorEvents() throws Exception {
		String gateway = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/AiGateway.java"), StandardCharsets.UTF_8);

		Method recommendStream = AiController.class.getMethod("recommendStream", Map.class);
		Method chatStream = AiController.class.getMethod("chatStream", Map.class);
		Assertions.assertArrayEquals(new String[]{"application/x-ndjson"}, recommendStream.getAnnotation(PostMapping.class).produces());
		Assertions.assertArrayEquals(new String[]{"application/x-ndjson"}, chatStream.getAnnotation(PostMapping.class).produces());
		Assertions.assertTrue(gateway.contains("writeStreamError(output"));
		Assertions.assertTrue(gateway.contains("event.put(\"type\", \"error\")"));
		Assertions.assertTrue(gateway.contains("AI 流式传输失败"));
	}

	@Test
	void bookControllerExposesStoreEndpoint() throws Exception {
		Method store = BookController.class.getMethod("store", String.class, long.class, int.class, int.class);
		Assertions.assertArrayEquals(new String[]{"/store"}, store.getAnnotation(GetMapping.class).value());
	}

	@Test
	void importControllerExposesBookImportEndpoint() throws Exception {
		Method importBook = ImportController.class.getMethod("importBook", Map.class);
		Assertions.assertArrayEquals(new String[]{"/books"}, importBook.getAnnotation(PostMapping.class).value());
	}

	@Test
	void recommendEnrichmentIncludesPersonalizationContext() throws Exception {
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);
		Assertions.assertTrue(service.contains("candidate_books"));
		Assertions.assertTrue(service.contains("reading_history"));
		Assertions.assertTrue(service.contains("favorites"));
		Assertions.assertTrue(service.contains("chat_records"));
		Assertions.assertTrue(service.contains("retrieved_chunks"));
	}

	@Test
	void repositoryExposesTopRatedFallbackOrdering() throws Exception {
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(repository.contains("public List<Map<String, Object>> topRatedBooks(int page, int size)"));
		Assertions.assertTrue(repository.contains("ORDER BY rating DESC, rating_count DESC, readerCount DESC, readable DESC"));
		Assertions.assertTrue(repository.contains("sql.append(\" ORDER BY rating DESC, rating_count DESC, readerCount DESC, readable DESC"));
		Assertions.assertTrue(repository.contains("sql.append(\"rating DESC, rating_count DESC, readerCount DESC, readable DESC"));
	}

	@Test
	void recommendFallsBackToTopRatedBooksForWeakSignalsAndWeakAi() throws Exception {
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(service.contains("query.isBlank() && !hasHabitSignals"));
		Assertions.assertTrue(service.contains("repository.topRatedBooks(page, 8)"));
		Assertions.assertTrue(service.contains("enriched.put(\"fallback_strategy\", \"top_rated_fallback\")"));
		Assertions.assertTrue(service.contains("isWeakRecommendResult(result)"));
		Assertions.assertTrue(service.contains("topRatedFallbackResult(context.query(), repository.topRatedBooks(context.page(), 8)"));
		Assertions.assertTrue(service.contains("result.put(\"llm_status\", \"top_rated_fallback\")"));
		Assertions.assertTrue(service.contains("\"tool\", \"top_rated_fallback\""));
	}

	@Test
	void seedMetadataPreservesAndDisplaysRatings() throws Exception {
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);
		String data = Files.readString(Path.of("src/main/resources/data.sql"), StandardCharsets.UTF_8);

		Assertions.assertTrue(repository.contains("rating = COALESCE(rating, 0)"));
		Assertions.assertTrue(repository.contains("rating_count = COALESCE(rating_count, 0)"));
		Assertions.assertFalse(repository.contains("b.rating = 0"));
		Assertions.assertFalse(repository.contains("b.rating_count = 0"));
		Assertions.assertTrue(repository.contains("WHEN b.rating > 0 THEN b.rating"));
		Assertions.assertTrue(repository.contains("b.rating_count = CASE WHEN b.rating_count > 0 THEN b.rating_count ELSE 420 + m.id * 37 END"));
		Assertions.assertTrue(repository.contains("；评分："));

		Assertions.assertTrue(data.contains("WHEN b.rating > 0 THEN b.rating"));
		Assertions.assertTrue(data.contains("b.rating_count = CASE WHEN b.rating_count > 0 THEN b.rating_count ELSE 420 + m.id * 37 END"));
		Assertions.assertTrue(data.contains("；评分："));
	}

	@Test
	void bookScopedChunkFallbackDoesNotLeakAcrossBooks() throws Exception {
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);
		Assertions.assertTrue(repository.contains("if (bookId != null && bookId > 0)"));
		Assertions.assertTrue(repository.contains("WHERE c.book_id = ?"));
	}

	@Test
	void dataSqlCorrectsSeedChapterAlignment() throws Exception {
		String data = Files.readString(Path.of("src/main/resources/data.sql"), StandardCharsets.UTF_8);
		Assertions.assertTrue(data.contains("修正 5-20 号可读章节"));
		Assertions.assertTrue(data.contains("阅读《深入理解计算机系统》"));
	}

	@Test
	void loginRegisterEndpointsPersistAuthIdentity() throws Exception {
		Method login = UserController.class.getMethod("login", Map.class);
		Method register = UserController.class.getMethod("register", Map.class);
		Method providerLogin = UserController.class.getMethod("providerLogin", Map.class);

		Assertions.assertArrayEquals(new String[]{"/login"}, login.getAnnotation(PostMapping.class).value());
		Assertions.assertArrayEquals(new String[]{"/register"}, register.getAnnotation(PostMapping.class).value());
		Assertions.assertArrayEquals(new String[]{"/provider-login"}, providerLogin.getAnnotation(PostMapping.class).value());

		String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);
		Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS user_auth"));
		Assertions.assertTrue(schema.contains("UNIQUE KEY uk_user_auth_provider_subject"));
		Assertions.assertTrue(repository.contains("ensureAuthTable()"));
		Assertions.assertTrue(repository.contains("CREATE TABLE IF NOT EXISTS user_auth"));
		Assertions.assertTrue(service.contains("changePassword(Map<String, Object> payload)"));
		Assertions.assertTrue(service.contains("resetPassword(Map<String, Object> payload)"));
	}

	@Test
	void userSchemaMigrationKeepsRegistrationIdAutoIncrement() throws Exception {
		String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(schema.contains("id BIGINT PRIMARY KEY AUTO_INCREMENT"));
		Assertions.assertTrue(schema.contains("email VARCHAR(160) NOT NULL DEFAULT ''"));
		Assertions.assertTrue(repository.contains("ensureUserIdAutoIncrement()"));
		Assertions.assertTrue(repository.contains("ALTER TABLE `user` MODIFY id BIGINT NOT NULL AUTO_INCREMENT"));
		Assertions.assertTrue(repository.contains("INSERT INTO `user` (account, phone, email, password_hash"));
	}

	@Test
	void planProgressUpdateIsScopedToCurrentUser() throws Exception {
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(service.contains("Payloads.number(payload, \"user_id\""));
		Assertions.assertTrue(service.contains("repository.updatePlan(userId, planId"));
		Assertions.assertTrue(repository.contains("WHERE id = ? AND user_id = ?"));
	}

}
