FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y lua5.1 lua5.1-dev git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p /app/modules

ENV LUA_PATH="/app/modules/?.lua;;"

CMD ["python", "bot.py"]
