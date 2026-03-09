from datetime import datetime
import resend
from app.config import get_settings

settings = get_settings()
resend.api_key = settings.resend_api_key


def send_detection_email(to_email: str, ad_name: str, detected_at: datetime, confidence: float, evidence_url: str | None):
    html = f"""
    <h2>זוהה תשדיר ברדיו</h2>
    <p><strong>תשדיר:</strong> {ad_name}</p>
    <p><strong>זמן שידור:</strong> {detected_at}</p>
    <p><strong>ודאות:</strong> {confidence:.2%}</p>
    <p><strong>קטע הוכחה:</strong> {'<a href="' + evidence_url + '">פתח קטע</a>' if evidence_url else 'אין כרגע'}</p>
    """
    resend.Emails.send({
        "from": settings.resend_from_email,
        "to": [to_email],
        "subject": f"זוהה תשדיר: {ad_name}",
        "html": html,
    })


def send_daily_report(to_email: str, report_date: str, rows_html: str):
    html = f"""
    <h2>דוח יומי – {report_date}</h2>
    <table border="1" cellpadding="8" cellspacing="0">
      <tr><th>תשדיר</th><th>שעה</th><th>ודאות</th><th>הוכחה</th></tr>
      {rows_html}
    </table>
    """
    resend.Emails.send({
        "from": settings.resend_from_email,
        "to": [to_email],
        "subject": f"דוח יומי תשדירים – {report_date}",
        "html": html,
    })
