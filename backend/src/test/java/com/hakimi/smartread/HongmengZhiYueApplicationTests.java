package com.hakimi.smartread;

import com.hakimi.smartread.api.ApiResponse;
import com.hakimi.smartread.controller.BookController;
import com.hakimi.smartread.repository.SmartReadRepository;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.GetMapping;

import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

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

}
