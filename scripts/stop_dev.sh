#!/bin/bash

echo "🛑 Остановка всех сервисов Notes Vault..."

cd "$(dirname "$0")/.."

# Остановка процессов по PID файлам
if [ -f .django.pid ]; then
    PID=$(cat .django.pid)
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo "✅ Django сервер остановлен"
    fi
    rm .django.pid
fi

if [ -f .celery_worker.pid ]; then
    PID=$(cat .celery_worker.pid)
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo "✅ Celery worker остановлен"
    fi
    rm .celery_worker.pid
fi

if [ -f .celery_beat.pid ]; then
    PID=$(cat .celery_beat.pid)
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo "✅ Celery beat остановлен"
    fi
    rm .celery_beat.pid
fi

if [ -f .fastapi.pid ]; then
    PID=$(cat .fastapi.pid)
    if ps -p $PID > /dev/null 2>&1; then
        kill $PID
        echo "✅ FastAPI сервер остановлен"
    fi
    rm .fastapi.pid
fi

# Остановка Docker Compose (опционально)
read -p "Остановить Docker Compose (Postgres и Redis)? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down
    echo "✅ Docker Compose остановлен"
fi

echo "✅ Все сервисы остановлены"
