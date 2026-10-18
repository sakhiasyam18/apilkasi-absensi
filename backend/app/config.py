from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    db_path: str = "./presensi.db"
    storage_dir: str = "./storage"
    model_name: str = "buffalo_l"
    det_size: int = 1280
    min_det_score: float = 0.5
    max_image_side: int = 1920
    reg_min_det_score: float = 0.6
    reg_min_self_similarity: float = 0.30
    match_threshold: float = 0.40
    max_captures_per_session: int = 5
    points_present: int = 10
    points_absent: int = -10
    max_upload_mb: int = 10

    class Config:
        env_file = ".env"

settings = Settings()