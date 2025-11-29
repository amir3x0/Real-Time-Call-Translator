from pydantic_settings import BaseSettings
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
    JWT_SECRET_KEY: str = Field("supersecret", env="JWT_SECRET_KEY")
    JWT_ALGORITHM: str = Field("HS256", env="JWT_ALGORITHM")
    JWT_EXP_DAYS: int = Field(7, env="JWT_EXP_DAYS")

    class Config:
        # .env file location - look in parent directories
        env_file = ".env"
        extra = "ignore"
        env_file_encoding = "utf-8"


settings = Settings()
