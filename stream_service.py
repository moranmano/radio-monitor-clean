body {
  font-family: Arial, sans-serif;
  margin: 0;
  background: #f6f8fb;
  color: #1f2937;
}

.layout {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  width: 240px;
  background: #111827;
  color: white;
  padding: 24px;
}

.sidebar h2 {
  margin-top: 0;
}

.sidebar nav {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.sidebar a {
  color: white;
  text-decoration: none;
  background: #1f2937;
  padding: 10px 12px;
  border-radius: 8px;
}

.main {
  flex: 1;
  padding: 32px;
}

.cards {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.card, .panel {
  background: white;
  border-radius: 14px;
  padding: 18px;
  box-shadow: 0 2px 14px rgba(0,0,0,0.05);
}

.label {
  font-size: 14px;
  color: #6b7280;
  margin-bottom: 8px;
}

.value {
  font-size: 28px;
  font-weight: bold;
}

.value.small {
  font-size: 14px;
  line-height: 1.5;
}

form {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

input, textarea, button {
  font: inherit;
  padding: 12px;
  border-radius: 10px;
  border: 1px solid #d1d5db;
}

button {
  background: #2563eb;
  color: white;
  border: none;
  cursor: pointer;
}

button:hover {
  background: #1d4ed8;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  border-radius: 14px;
  overflow: hidden;
}

th, td {
  text-align: right;
  padding: 12px;
  border-bottom: 1px solid #e5e7eb;
}

th {
  background: #eff6ff;
}

.login-body {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
}

.login-box {
  width: 360px;
  background: white;
  padding: 28px;
  border-radius: 16px;
  box-shadow: 0 5px 18px rgba(0,0,0,0.08);
}

.error {
  margin-top: 12px;
  color: #b91c1c;
}
