# ⚠️ VOLONTAIREMENT VULNÉRABLE - SUPPORT PÉDAGOGIQUE
import os
from flask import Flask

app = Flask(__name__)
SECRET_KEY = os.environ.get("SECRET_KEY", "super-secret-key-1234")


@app.route("/")
def index():
    return "Hello from the vulnerable app"


@app.route("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    # Mode debug activé et écoute sur toutes les interfaces
    app.run(host="0.0.0.0", port=5000, debug=True)
