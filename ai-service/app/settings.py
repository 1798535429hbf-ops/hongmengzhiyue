import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_float(name: str, default: float) -> float:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return float(value)
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    mysql_host: str = os.getenv("MYSQL_HOST", "127.0.0.1")
    mysql_port: int = int(os.getenv("MYSQL_PORT", "3306"))
    mysql_user: str = os.getenv("MYSQL_USER", "root")
    mysql_password: str = os.getenv("MYSQL_PASSWORD", "")
    mysql_database: str = os.getenv("MYSQL_DATABASE", "hongmeng_zhiyue")
    deepseek_base_url: str = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
    deepseek_model: str = os.getenv("DEEPSEEK_MODEL", "deepseek-v4-pro")
    deepseek_thinking: str = os.getenv("DEEPSEEK_THINKING", "disabled")
    deepseek_max_tokens: int = int(os.getenv("DEEPSEEK_MAX_TOKENS", "2048"))
    deepseek_temperature: float = env_float("DEEPSEEK_TEMPERATURE", 0.6)
    deepseek_use_proxy: bool = env_bool("DEEPSEEK_USE_PROXY", False)
    deepseek_api_key: str = os.getenv("DEEPSEEK_API_KEY", "")

    def require_runtime(self) -> None:
        if not self.deepseek_api_key:
            raise RuntimeError("DEEPSEEK_API_KEY is required for the AI service")


settings = Settings()
