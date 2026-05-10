from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "DevSecOps Demo API"
    env: str = "development"
    log_level: str = "INFO"
    secret_key: str = "override-me-via-env-var"  # noqa: S105
    access_token_expire_minutes: int = 30

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
