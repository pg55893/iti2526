# Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv build-essential ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

# user não-root
RUN useradd -u 1000 -m webapp
WORKDIR /app

COPY requirements.txt .
RUN pip3 install -r requirements.txt && pip3 install gunicorn

COPY . .
RUN chown -R webapp:webapp /app
USER webapp

EXPOSE 8080
# "App.py" => módulo "App"; assume variável Flask chamada "app" lá dentro
CMD ["gunicorn","-w","3","-k","gthread","-b","0.0.0.0:8080","App:app","--timeout","60"]
