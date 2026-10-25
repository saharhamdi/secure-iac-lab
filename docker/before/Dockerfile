# ⚠️ VOLONTAIREMENT VULNÉRABLE - SUPPORT PÉDAGOGIQUE
FROM python:latest

# Secret en dur dans l'image
ENV SECRET_KEY="super-secret-key-1234"
ENV DB_PASSWORD="admin123"

WORKDIR /app

# ADD au lieu de COPY
ADD . /app

RUN pip install flask

EXPOSE 22 5000

# Exécution en root, pas de HEALTHCHECK
CMD ["python", "app.py"]
