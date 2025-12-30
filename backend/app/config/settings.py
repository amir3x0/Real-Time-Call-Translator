from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    # Database
    DB_USER: str = Field("translator_admin")
    DB_PASSWORD: str = Field("TranslatorPass2024")
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

    # App
    API_HOST: str = Field("0.0.0.0")
    API_PORT: int = Field(8000)
    DEBUG: bool = Field(True)
    JWT_SECRET_KEY: str = Field("supersecret")
    JWT_ALGORITHM: str = Field("HS256")
    JWT_EXP_DAYS: int = Field(7)
    
    # File Storage Paths
    DATA_DIR: str = Field("/app/data")
    VOICE_SAMPLES_DIR: str = Field("/app/data/voice_samples")
    UPLOADS_DIR: str = Field("/app/data/uploads")
    MODELS_DIR: str = Field("/app/data/models")

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
        env_file_encoding="utf-8"
    )


settings = Settings()
