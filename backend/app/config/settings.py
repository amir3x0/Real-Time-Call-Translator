from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    # Database
    DB_USER: str = Field("translator_admin")
    DB_PASSWORD: str = Field("changeme")
    DB_NAME: str = Field("call_translator")
    DB_HOST: str = Field("postgres")
    DB_PORT: int = Field(5432)

    # Redis
    REDIS_HOST: str = Field("redis")
    REDIS_PORT: int = Field(6379)
    REDIS_PASSWORD: str | None = Field(None)

    # Google Cloud
    GOOGLE_APPLICATION_CREDENTIALS: str | None = Field(None)
    GOOGLE_PROJECT_ID: str | None = Field(None)

    # Chatterbox TTS
    CHATTERBOX_DEVICE: str = Field("cpu")  # "cuda" or "cpu"
    CHATTERBOX_VOICE_SAMPLES_DIR: str = Field("/app/data/voice_samples")
    CHATTERBOX_MODELS_DIR: str = Field("/app/data/models")

    # App
    API_HOST: str = Field("0.0.0.0")
    API_PORT: int = Field(8000)
    DEBUG: bool = Field(True)

    class Config:
        # .env is in the backend/ directory relative to this file
        env_file = "../../.env"
        env_file_encoding = "utf-8"


settings = Settings()
