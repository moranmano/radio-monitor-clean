import io
from pathlib import Path
from supabase import create_client, Client
from app.config import get_settings

settings = get_settings()
_supabase: Client | None = None


def get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        _supabase = create_client(settings.supabase_url, settings.supabase_key)
    return _supabase


def upload_bytes(bucket: str, path: str, content: bytes, content_type: str) -> None:
    sb = get_supabase()
    sb.storage.from_(bucket).upload(
        path=path,
        file=io.BytesIO(content),
        file_options={"content-type": content_type, "upsert": "true"},
    )


def download_bytes(bucket: str, path: str) -> bytes:
    sb = get_supabase()
    return sb.storage.from_(bucket).download(path)


def get_public_url(bucket: str, path: str) -> str:
    sb = get_supabase()
    return sb.storage.from_(bucket).get_public_url(path)


def extension_for(filename: str) -> str:
    ext = Path(filename).suffix.lower()
    return ext if ext else '.bin'
