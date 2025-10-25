# syntax=docker/dockerfile:1
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    POETRY_VIRTUALENVS_CREATE=false

WORKDIR /app

COPY sira_api_v3/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY sira_api_v3/app ./app
COPY sira_api_v3/.env.example .env.example

EXPOSE 8791

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8791"]
