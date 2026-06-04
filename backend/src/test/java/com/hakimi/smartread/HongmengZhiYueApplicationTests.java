package com.hakimi.smartread;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.controller.BookController;
import com.hakimi.smartread.controller.ImportController;
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
	void chatEnrichesPayloadWithBookSources() throws Exception {
		String service = Files.readString(Path.of("src/main/java/com/hakimi/smartread/service/SmartReadService.java"), StandardCharsets.UTF_8);
		Assertions.assertTrue(service.contains("enriched.put(\"sources\", repository.findChunks"));
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
		Assertions.assertTrue(schema.contains("CREATE TABLE IF NOT EXISTS user_auth"));
		Assertions.assertTrue(schema.contains("UNIQUE KEY uk_user_auth_provider_subject"));
		Assertions.assertTrue(repository.contains("ensureAuthTable()"));
		Assertions.assertTrue(repository.contains("CREATE TABLE IF NOT EXISTS user_auth"));
	}

	@Test
	void userSchemaMigrationKeepsRegistrationIdAutoIncrement() throws Exception {
		String schema = Files.readString(Path.of("src/main/resources/schema.sql"), StandardCharsets.UTF_8);
		String repository = Files.readString(Path.of("src/main/java/com/hakimi/smartread/repository/SmartReadRepository.java"), StandardCharsets.UTF_8);

		Assertions.assertTrue(schema.contains("id BIGINT PRIMARY KEY AUTO_INCREMENT"));
		Assertions.assertTrue(repository.contains("ensureUserIdAutoIncrement()"));
		Assertions.assertTrue(repository.contains("ALTER TABLE `user` MODIFY id BIGINT NOT NULL AUTO_INCREMENT"));
		Assertions.assertTrue(repository.contains("INSERT INTO `user` (account, phone, password_hash"));
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
