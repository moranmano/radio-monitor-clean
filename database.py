from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from sqlalchemy import select
from sqlalchemy.orm import Session
from app.config import get_settings
from app.models import Detection, SettingsModel
from app.services.email_service import send_daily_report


settings = get_settings()


def send_yesterday_report(db: Session):
    tz = ZoneInfo(settings.timezone)
    now = datetime.now(tz)
    start = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=1)

    rows = db.execute(
        select(Detection).where(Detection.detected_at >= start, Detection.detected_at < end).order_by(Detection.detected_at.asc())
    ).scalars().all()

    settings_row = db.get(SettingsModel, 1)
    to_email = settings_row.report_email if settings_row else settings.default_report_email

    if not rows:
        rows_html = '<tr><td colspan="4">לא נמצאו זיהויים אתמול</td></tr>'
    else:
        rows_html = ''.join(
            f"<tr><td>{row.ad_name_snapshot}</td><td>{row.detected_at.astimezone(tz).strftime('%H:%M:%S')}</td><td>{row.confidence:.2%}</td><td>{f'<a href=\"{row.evidence_public_url}\">פתח</a>' if row.evidence_public_url else ''}</td></tr>"
            for row in rows
        )

    send_daily_report(to_email=to_email, report_date=start.strftime('%Y-%m-%d'), rows_html=rows_html)
