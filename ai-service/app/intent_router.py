from typing import Literal


Intent = Literal["recommend", "chat", "summary", "plan", "commerce", "insufficient"]


def route_intent(text: str) -> Intent:
    query = (text or "").strip()
    if not query:
        return "recommend"
    commerce_words = ("购买", "借", "馆藏", "图书馆", "二手", "价格", "渠道")
    plan_words = ("计划", "几天", "安排", "进度", "打卡")
    summary_words = ("总结", "摘要", "重点", "复习")
    recommend_words = ("推荐", "想读", "想看", "找", "考研", "入门", "书籍", "书")
    if any(word in query for word in commerce_words):
        return "commerce"
    if any(word in query for word in plan_words):
        return "plan"
    if any(word in query for word in summary_words):
        return "summary"
    if any(word in query for word in recommend_words):
        return "recommend"
    return "recommend"
