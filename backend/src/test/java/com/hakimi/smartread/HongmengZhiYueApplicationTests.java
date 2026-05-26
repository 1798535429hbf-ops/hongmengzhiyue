package com.hakimi.smartread;

import com.hakimi.smartread.api.ApiResponse;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

class HongmengZhiYueApplicationTests {

	@Test
	void apiResponseUsesPrdEnvelope() {
		ApiResponse<String> response = ApiResponse.ok("done");
		Assertions.assertEquals(0, response.code());
		Assertions.assertEquals("ok", response.message());
		Assertions.assertEquals("done", response.data());
	}

}
