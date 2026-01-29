from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    All sensitive values (passwords, secrets) must be provided via environment
    variables or .env file. No default values are provided for security.
    """

    # Database - PostgreSQL connection settings
    DB_USER: str = Field(default="translator_admin", description="Database username")
    DB_PASSWORD: str = Field(description="Database password (required)")
    DB_NAME: str = Field(default="call_translator", description="Database name")
    DB_HOST: str = Field(default="localhost", description="Database host")
    DB_PORT: int = Field(default=5432, description="Database port")

    # Redis - Cache and message broker settings
    REDIS_HOST: str = Field(default="localhost", description="Redis host")
    REDIS_PORT: int = Field(default=6379, description="Redis port")
    REDIS_PASSWORD: str | None = Field(default=None, description="Redis password")

    # Google Cloud Platform - AI services configuration
    GOOGLE_APPLICATION_CREDENTIALS: str | None = Field(
        default=None,
        description="Path to GCP service account JSON file"
    )
    GOOGLE_PROJECT_ID: str | None = Field(
        default=None,
        description="GCP project ID for Speech/Translation/TTS APIs"
    )

    # Vertex AI - Region for Gemini context resolution
    VERTEX_AI_LOCATION: str = Field(
        default="us-central1",
        description="GCP region for Vertex AI services"
    )

    # Application server settings
    API_HOST: str = Field(default="0.0.0.0", description="API bind address")
    API_PORT: int = Field(default=8000, description="API port")
    API_PUBLIC_HOST: str | None = Field(
        default=None,
        description="Public hostname for WebSocket URLs (when API_HOST is 0.0.0.0)"
    )
    DEBUG: bool = Field(default=False, description="Enable debug mode")

    # JWT Authentication - MUST be set via environment variable
    JWT_SECRET_KEY: str = Field(description="Secret key for JWT signing (required)")
    JWT_ALGORITHM: str = Field(default="HS256", description="JWT signing algorithm")
    JWT_EXP_DAYS: int = Field(default=7, description="JWT token expiration in days")
    
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
