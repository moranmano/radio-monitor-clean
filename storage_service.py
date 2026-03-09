{% extends 'base.html' %}
{% block content %}
<h1>זיהויים</h1>
<table>
  <thead>
    <tr>
      <th>תשדיר</th>
      <th>זמן שידור</th>
      <th>ודאות</th>
      <th>הוכחה</th>
      <th>הערה</th>
    </tr>
  </thead>
  <tbody>
    {% for row in rows %}
    <tr>
      <td>{{ row.ad_name_snapshot }}</td>
      <td>{{ row.detected_at }}</td>
      <td>{{ '%.2f%%'|format(row.confidence * 100) }}</td>
      <td>{% if row.evidence_public_url %}<a href="{{ row.evidence_public_url }}" target="_blank">האזן</a>{% endif %}</td>
      <td>{{ row.notes or '' }}</td>
    </tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
