import os
from pathlib import Path

from flask import Flask

app = Flask(__name__)


def read_secret(name: str) -> str:
    """Lit un secret depuis un fichier (Docker secret) ou une variable *_FILE."""
    path = os.environ.get(f"{name}_FILE")
    if path and Path(path).is_file():
        return Path(path).read_text(encoding="utf-8").strip()
    raise RuntimeError(f"Secret {name} manquant : definir {name}_FILE")


app.config["SECRET_KEY"] = read_secret("SECRET_KEY")


@app.route("/")
def index():
    return "Hello from the hardened app"


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    # Debug désactivé ; l'exposition est limitée par le compose (127.0.0.1)
    app.run(host="0.0.0.0", port=5000, debug=False)
