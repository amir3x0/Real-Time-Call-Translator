from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    # Database
    DB_USER: str = Field(default="translator_admin")
    DB_PASSWORD: str = Field(default="TranslatorPass2024")
    DB_NAME: str = Field(default="call_translator")
    DB_HOST: str = Field(default="postgres")
    DB_PORT: int = Field(default=5432)

    # Redis
    REDIS_HOST: str = Field(default="redis")
    REDIS_PORT: int = Field(default=6379)
    REDIS_PASSWORD: str | None = Field(default=None)

    # Google Cloud
    GOOGLE_APPLICATION_CREDENTIALS: str | None = Field(default=None)
    GOOGLE_PROJECT_ID: str | None = Field(default=None)

    # App
    API_HOST: str = Field(default="0.0.0.0")
    API_PORT: int = Field(default=8000)
    # Public host for WebSocket URLs (use actual IP/hostname clients can reach)
    # Set via API_PUBLIC_HOST env var when API_HOST is 0.0.0.0
    API_PUBLIC_HOST: str | None = Field(default=None)
    DEBUG: bool = Field(default=True)
    JWT_SECRET_KEY: str = Field(default="supersecret")
    JWT_ALGORITHM: str = Field(default="HS256")
    JWT_EXP_DAYS: int = Field(default=7)
    
    # CORS
    BACKEND_CORS_ORIGINS: list[str] = Field(default=["http://localhost", "http://localhost:3000", "http://127.0.0.1", "http://127.0.0.1:3000"])

    # File Storage Paths
    DATA_DIR: str = Field(default="/app/data")
    VOICE_SAMPLES_DIR: str = Field(default="/app/data/voice_samples")
    UPLOADS_DIR: str = Field(default="/app/data/uploads")
    MODELS_DIR: str = Field(default="/app/data/models")

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
        env_file_encoding="utf-8"
    )


settings = Settings()
