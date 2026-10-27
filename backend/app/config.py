from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "dev"
    database_url: str = "sqlite:///./signbridge.db"
    secret_key: str = "change-me-in-production"
    access_token_minutes: int = 60 * 24
    cors_origins: str = "*"
    media_dir: str = "media"
    models_dir: str = "models"
    max_upload_mb: int = 20

    llm_base_url: str = ""
    llm_api_key: str = ""
    llm_model: str = ""
    llm_timeout: float = 15.0

    enable_stt: bool = False
    whisper_model: str = "small"
    enable_tts: bool = False

    sign_threshold: float = 0.7
    word_gap_seconds: float = 0.5
    sentence_gap_seconds: float = 1.5
    min_word_frames: int = 4

    firebase_project_id: str = ""      # set this to turn on Firebase / Google login
    allow_local_auth: bool = False      # keep plain email+password endpoints even when Firebase is on
    admin_email: str = ""
    admin_password: str = ""

    @property
    def local_auth_enabled(self) -> bool:
        return (not self.firebase_project_id) or self.allow_local_auth

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()] or ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()
