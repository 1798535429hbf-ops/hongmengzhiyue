import unittest

from app.output_parser import normalize_chat, normalize_recommend


class OutputParserFallbackTests(unittest.TestCase):
    def test_recommend_uses_candidates_for_empty_llm_output(self) -> None:
        result = normalize_recommend(
            {},
            candidate_books=[
                {
                    "id": 2,
                    "title": "机器学习",
                    "author": "周志华",
                    "difficulty": "进阶",
                    "summary": "系统讲解机器学习基本概念、模型与评估方法，适合课程拓展和竞赛基础。",
                    "rating": "4.9",
                    "ratingCount": "1280",
                },
                {
                    "id": 4,
                    "title": "算法图解",
                    "author": "Aditya Bhargava",
                    "difficulty": "入门",
                    "summary": "用图示解释算法和数据结构，适合先建立直觉。",
                    "rating": "4.8",
                    "ratingCount": "960",
                },
            ],
            sources=[],
            tool_trace=[{"tool": "top_rated_fallback", "status": "ok"}],
        )

        self.assertEqual("recovered", result["llm_status"])
        self.assertGreaterEqual(len(result["book_list"]), 2)
        self.assertIn("机器学习", result["reason"])
        self.assertIn("书库评分", result["book_list"][0]["reason"])
        self.assertNotIn("换成更具体", result["follow_up_suggestion"])
        self.assertNotIn("告诉我你想", result["follow_up_suggestion"])

    def test_chat_expands_weak_answer_with_source_context(self) -> None:
        result = normalize_chat(
            {"answer": "可以。", "sources": [], "llm_status": "ok"},
            sources=[
                {
                    "chunk_id": 11,
                    "book_id": 2,
                    "title": "机器学习",
                    "source": "chapter-1",
                    "text": "本章先说明监督学习、泛化能力和模型评估的关系。",
                }
            ],
            tool_trace=[{"tool": "rag_retrieve", "status": "ok"}],
        )

        self.assertEqual("recovered", result["llm_status"])
        self.assertGreater(len(result["answer"]), 50)
        self.assertIn("监督学习", result["answer"])
        self.assertEqual(1, len(result["sources"]))
        self.assertNotIn("发我一段正文", result["follow_up_suggestion"])

    def test_chat_without_sources_returns_general_guidance_without_sources(self) -> None:
        result = normalize_chat(
            {"answer": "", "sources": [], "llm_status": "parser_failed"},
            sources=[],
            tool_trace=[{"tool": "rag_retrieve", "status": "ok"}],
        )

        self.assertEqual("general_guidance", result["llm_status"])
        self.assertEqual([], result["sources"])
        self.assertEqual("先补一段章节片段，或者把问题缩到具体章节。", result["follow_up_suggestion"])
        self.assertGreater(len(result["answer"]), 50)
        self.assertIn("正文片段", result["answer"])


if __name__ == "__main__":
    unittest.main()
