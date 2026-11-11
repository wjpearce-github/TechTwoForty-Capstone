import app as notes_app
from app import app


def test_health():
    resp = app.test_client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_security_headers():
    resp = app.test_client().get("/health")
    assert resp.headers["X-Content-Type-Options"] == "nosniff"
    assert resp.headers["Content-Security-Policy"].startswith("default-src 'self'")
    assert resp.headers["Permissions-Policy"] == "camera=(), microphone=(), geolocation=()"


def test_notes_are_escaped(monkeypatch):
    # A note containing a script tag must be shown as text, never run.
    monkeypatch.setattr(notes_app, "list_notes", lambda: ["<script>alert(1)</script>"])
    resp = app.test_client().get("/")
    assert resp.status_code == 200
    assert b"<script>alert(1)</script>" not in resp.data
    assert b"&lt;script&gt;alert(1)&lt;/script&gt;" in resp.data
