#!/bin/bash

set -e

echo "🚀 Запуск проекта Notes Vault..."

# Переход в корневую директорию проекта
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Определение Python интерпретатора
PYTHON_CMD="python3"
if [ -z "$VIRTUAL_ENV" ]; then
    if [ -d "$PROJECT_ROOT/venv" ] && [ -f "$PROJECT_ROOT/venv/bin/python" ]; then
        echo "🔧 Использование Python из виртуального окружения..."
        PYTHON_CMD="$PROJECT_ROOT/venv/bin/python"
    elif [ -d "$PROJECT_ROOT/.venv" ] && [ -f "$PROJECT_ROOT/.venv/bin/python" ]; then
        echo "🔧 Использование Python из виртуального окружения..."
        PYTHON_CMD="$PROJECT_ROOT/.venv/bin/python"
    else
        echo "⚠️  Виртуальное окружение не найдено."
        echo "   Создайте его командой: python3 -m venv venv"
        echo "   Затем активируйте: source venv/bin/activate"
        echo "   И установите зависимости: pip install -r requirements.txt"
        read -p "Продолжить без виртуального окружения? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    PYTHON_CMD="python"
fi

# Проверка наличия Django
if ! $PYTHON_CMD -c "import django" 2>/dev/null; then
    echo "❌ Django не установлен. Установите зависимости:"
    echo "   pip install -r requirements.txt"
    exit 1
fi

# Проверка наличия .env файла
if [ ! -f .env ]; then
    echo "⚠️  Файл .env не найден. Создаю из .env.example..."
    cp .env.example .env

    # Генерация SECRET_KEY и ENCRYPTION_KEY
    echo "🔑 Генерация SECRET_KEY и ENCRYPTION_KEY..."
    SECRET_KEY=$($PYTHON_CMD -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || $PYTHON_CMD -c "import secrets; print(secrets.token_urlsafe(50))")
    ENCRYPTION_KEY=$($PYTHON_CMD -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || echo "CHANGE_ME_GENERATE_NEW_KEY")

    # Замена значений в .env файле
    if [ -n "$SECRET_KEY" ] && [ "$SECRET_KEY" != "CHANGE_ME_GENERATE_NEW_KEY" ]; then
        sed -i "s|SECRET_KEY=.*|SECRET_KEY=$SECRET_KEY|" .env
        echo "✅ SECRET_KEY сгенерирован и установлен"
    fi

    if [ -n "$ENCRYPTION_KEY" ] && [ "$ENCRYPTION_KEY" != "CHANGE_ME_GENERATE_NEW_KEY" ]; then
        sed -i "s|ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$ENCRYPTION_KEY|" .env
        echo "✅ ENCRYPTION_KEY сгенерирован и установлен"
    fi

    if [ "$ENCRYPTION_KEY" = "CHANGE_ME_GENERATE_NEW_KEY" ]; then
        echo "⚠️  Не удалось автоматически сгенерировать ENCRYPTION_KEY"
        echo "   Сгенерируйте вручную: python3 -c \"from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())\""
        echo "   И установите его в .env файле"
        read -p "Продолжить запуск? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Запуск Docker Compose для Postgres и Redis
echo "📦 Запуск Docker Compose (Postgres и Redis)..."
docker-compose up -d

# Ожидание готовности PostgreSQL
echo "⏳ Ожидание готовности PostgreSQL..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec notes_vault_postgres pg_isready -U notes_user >/dev/null 2>&1; then
        echo "✅ PostgreSQL готов к подключениям"
        break
    fi
    attempt=$((attempt + 1))
    echo "   Попытка $attempt/$max_attempts..."
    sleep 1
done
if [ $attempt -eq $max_attempts ]; then
    echo "❌ PostgreSQL не готов после $max_attempts попыток"
    exit 1
fi

# Создание миграций Django (если они не существуют)
echo "📝 Создание миграций Django..."
cd backend
$PYTHON_CMD manage.py makemigrations --noinput

# Применение миграций Django
echo "🔄 Применение миграций Django..."
$PYTHON_CMD manage.py migrate

# Создание суперпользователя (если не существует)
echo "👤 Проверка суперпользователя..."
$PYTHON_CMD manage.py shell << EOF
from users.models import User
if not User.objects.filter(is_superuser=True).exists():
    print("Создайте суперпользователя командой: $PYTHON_CMD manage.py createsuperuser")
EOF

cd ..

# Запуск сервисов в фоне
echo "🌐 Запуск Django сервера на порту 8000..."
cd backend
$PYTHON_CMD manage.py runserver 0.0.0.0:8000 > ../django_server.log 2>&1 &
DJANGO_PID=$!
cd ..

echo "⚙️  Запуск Celery worker..."
cd backend
celery -A core worker -l info > ../celery_worker.log 2>&1 &
CELERY_WORKER_PID=$!
cd ..

echo "⏰ Запуск Celery beat..."
cd backend
celery -A core beat -l info > ../celery_beat.log 2>&1 &
CELERY_BEAT_PID=$!
cd ..

echo "🚀 Запуск FastAPI сервера на порту 8001..."
#cd "$PROJECT_ROOT/fastapi_app"
uvicorn fastapi_app.main:app --host 0.0.0.0 --port 8001 --reload > ../fastapi_server.log 2>&1 &
FASTAPI_PID=$!
cd ..

# Сохранение PID процессов
echo $DJANGO_PID > .django.pid
echo $CELERY_WORKER_PID > .celery_worker.pid
echo $CELERY_BEAT_PID > .celery_beat.pid
echo $FASTAPI_PID > .fastapi.pid

echo ""
echo "✅ Все сервисы запущены!"
echo ""
echo "📍 Доступные эндпоинты:"
echo "   - Django Admin: http://localhost:8000/admin"
echo "   - Django API: http://localhost:8000/api/"
echo "   - FastAPI Docs: http://localhost:8001/docs"
echo "   - FastAPI Health: http://localhost:8001/health"
echo ""
echo "📋 Логи:"
echo "   - Django: django_server.log"
echo "   - Celery Worker: celery_worker.log"
echo "   - Celery Beat: celery_beat.log"
echo "   - FastAPI: fastapi_server.log"
echo ""
echo "🛑 Для остановки всех сервисов выполните: ./scripts/stop_dev.sh"
echo ""
