from typing import Literal


Intent = Literal[
    "recommend",
    "chat",
    "summary",
    "plan",
    "commerce",
    "interest_analysis",
    "smalltalk",
    "clarify",
    "insufficient",
]


def route_intent(text: str) -> Intent:
    query = (text or "").strip()
    if not query:
        return "recommend"
    smalltalk_words = ("你好", "您好", "嗨", "hi", "hello", "在吗", "你是谁", "你能干嘛")
    interest_words = ("我的兴趣", "阅读兴趣", "阅读倾向", "我喜欢什么", "分析我", "画像", "偏好")
    commerce_words = ("购买", "借", "馆藏", "图书馆", "二手", "价格", "渠道")
    plan_words = ("计划", "几天", "安排", "进度", "打卡")
    summary_words = ("总结", "摘要", "重点", "复习")
    recommend_words = ("推荐", "适合", "想读", "想看", "找", "挑", "考研", "入门", "书籍", "书",
                       "换一批", "再来一批", "猜你喜欢", "下一批", "更多推荐", "换书")
    if query.lower() in smalltalk_words or any(word == query for word in smalltalk_words):
        return "smalltalk"
    if any(word in query for word in commerce_words):
        return "commerce"
    if any(word in query for word in plan_words):
        return "plan"
    if any(word in query for word in summary_words):
        return "summary"
    if any(word in query for word in interest_words):
        return "interest_analysis"
    if any(word in query for word in recommend_words):
        return "recommend"
    if len(query) <= 6:
        return "clarify"
    return "chat"
