from datetime import datetime
from zoneinfo import ZoneInfo
from app.config import get_settings


def now_local() -> datetime:
    settings = get_settings()
    return datetime.now(ZoneInfo(settings.timezone))
