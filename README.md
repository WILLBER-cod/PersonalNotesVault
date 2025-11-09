# Личный Сейф для Заметок (Personal Notes Vault)

Веб-приложение для создания и хранения текстовых заметок с автоматическим шифрованием контента на стороне сервера.

## Технологический стек

- **Django & Django REST Framework** - основное веб-приложение и REST API
- **FastAPI** - легковесный API для health check
- **PostgreSQL** - основная база данных
- **Redis** - брокер сообщений для Celery
- **Celery** - фоновые задачи для отправки email статистики
- **Cryptography** - симметричное шифрование заметок
- **Bcrypt** - хеширование паролей (встроено в Django)

## Структура проекта

```
notes_vault/
├── docker-compose.yml          # Postgres и Redis
├── .env                        # Переменные окружения
├── backend/                    # Django проект
│   ├── manage.py
│   ├── core/                   # Основной проект Django
│   ├── notes/                  # Приложение для заметок
│   ├── users/                  # Приложение для пользователей
│   └── celery_app/             # Celery задачи
├── fastapi_app/                # FastAPI приложение
└── scripts/                    # Скрипты запуска
```

## Установка и запуск

### 1. Клонирование и настройка окружения

```bash
# Создание виртуального окружения
python -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows

# Установка зависимостей
pip install -r requirements.txt
```

### 2. Настройка переменных окружения

Скопируйте `.env.example` в `.env` и заполните необходимые значения:

```bash
cp .env.example .env
```

**Важно:** Сгенерируйте ключ шифрования:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Вставьте полученный ключ в `.env` файл в переменную `ENCRYPTION_KEY`.

### 3. Запуск проекта

```bash
./scripts/run_dev.sh
```

Скрипт автоматически:
- Запустит Docker Compose (Postgres и Redis)
- Применит миграции Django
- Запустит Django сервер (порт 8000)
- Запустит Celery worker
- Запустит Celery beat
- Запустит FastAPI сервер (порт 8001)

### 4. Остановка проекта

```bash
./scripts/stop_dev.sh
```

## API Эндпоинты

### Django REST Framework (http://localhost:8000)

#### Регистрация пользователя
```http
POST /api/register/
Content-Type: application/json

{
  "email": "user@example.com",
  "username": "username",
  "password": "password123",
  "password_confirm": "password123"
}
```

#### Вход
```http
POST /api/login/
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

#### CRUD для заметок
```http
# Список заметок
GET /api/notes/
Authorization: Token <your-token>

# Создание заметки
POST /api/notes/
Authorization: Token <your-token>
Content-Type: application/json

{
  "title": "Заголовок заметки",
  "content": "Содержимое заметки"
}

# Получение заметки
GET /api/notes/{id}/
Authorization: Token <your-token>

# Обновление заметки
PUT /api/notes/{id}/
Authorization: Token <your-token>
Content-Type: application/json

{
  "title": "Новый заголовок",
  "content": "Новое содержимое"
}

# Удаление заметки
DELETE /api/notes/{id}/
Authorization: Token <your-token>
```

### FastAPI (http://localhost:8001)

#### Health Check
```http
GET /health
```

Ответ:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T12:00:00"
}
```

## Особенности

### Шифрование заметок

Все заметки автоматически шифруются перед сохранением в базу данных с использованием симметричного шифрования (Fernet). При чтении заметки автоматически расшифровываются. В базе данных хранятся только зашифрованные данные.

### Ежедневная статистика

Celery Beat автоматически запускает задачу каждый день, которая отправляет пользователям email с количеством созданных за последние 24 часа заметок.

### Логирование

Логи записываются в файлы:
- `django.log` - логи Django
- `celery.log` - логи Celery
