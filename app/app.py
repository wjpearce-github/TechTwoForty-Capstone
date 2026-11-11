import json
import os

import boto3
import psycopg
from flask import Flask, jsonify, redirect, render_template, request, url_for

app = Flask(__name__)

# The deploy sets APP_VERSION to the Git commit ID, so you can always
# see exactly which version of the code is live.
VERSION = os.environ.get("APP_VERSION", "dev")


def db_credentials():
    """Return the database username and password.

    In AWS the password lives in Secrets Manager, and the app reads it
    using the server's IAM role: no keys, no .env file, nothing in Git.
    Locally, Docker Compose passes it in as DB_PASSWORD instead.
    """
    secret_arn = os.environ.get("DB_SECRET_ARN")
    if secret_arn:
        client = boto3.client("secretsmanager", region_name=os.environ.get("AWS_REGION", "eu-west-2"))
        secret = json.loads(client.get_secret_value(SecretId=secret_arn)["SecretString"])
        return secret["username"], secret["password"]
    return os.environ.get("DB_USER", "postgres"), os.environ["DB_PASSWORD"]


def connect():
    user, password = db_credentials()
    conn = psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ.get("DB_NAME", "postgres"),
        user=user,
        password=password,
        sslmode=os.environ.get("DB_SSLMODE", "prefer"),
        connect_timeout=5,
    )
    conn.execute(
        "CREATE TABLE IF NOT EXISTS notes ("
        " id SERIAL PRIMARY KEY,"
        " body TEXT NOT NULL,"
        " created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
    )
    return conn


def list_notes():
    with connect() as conn:
        rows = conn.execute("SELECT body FROM notes ORDER BY id DESC LIMIT 50").fetchall()
    return [row[0] for row in rows]


def add_note(body):
    with connect() as conn:
        conn.execute("INSERT INTO notes (body) VALUES (%s)", (body,))


@app.after_request
def security_headers(resp):
    resp.headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'; form-action 'self'"
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Referrer-Policy"] = "no-referrer"
    resp.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    return resp


@app.route("/health")
def health():
    # Answers without touching the database, so a slow database never
    # makes the load balancer think the whole server is dead.
    return jsonify(status="ok", version=VERSION)


@app.route("/")
def home():
    return render_template("index.html", notes=list_notes())


@app.route("/notes", methods=["POST"])
def create_note():
    body = request.form.get("body", "").strip()
    if body:
        add_note(body[:500])
    return redirect(url_for("home"))


@app.route("/api/notes")
def api_notes():
    return jsonify(notes=list_notes())
