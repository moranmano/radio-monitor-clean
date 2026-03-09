{% extends 'base.html' %}
{% block content %}
<h1>הגדרות</h1>
<div class="panel">
  <form method="post" action="/settings">
    <label>מייל דוחות</label>
    <input type="email" name="report_email" value="{{ row.report_email if row else '' }}" required />

    <label>סטרים ראשי</label>
    <input type="text" name="stream_url" value="{{ row.stream_url if row else '' }}" required />

    <label>סטרימים חלופיים</label>
    <textarea name="stream_backup_urls">{{ row.stream_backup_urls if row else '' }}</textarea>

    <label>סף זיהוי</label>
    <input type="number" step="0.01" min="0.1" max="0.99" name="match_threshold" value="{{ row.match_threshold if row else 0.78 }}" required />

    <label>מניעת כפילויות בדקות</label>
    <input type="number" min="1" max="120" name="dedup_minutes" value="{{ row.dedup_minutes if row else 8 }}" required />

    <button type="submit">שמור</button>
  </form>
</div>
{% endblock %}
