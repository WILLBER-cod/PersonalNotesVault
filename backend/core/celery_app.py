import os
from celery import Celery
from django.conf import settings

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

app = Celery('notes_vault')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

app.conf.beat_schedule = {
    'send-daily-stats': {
        'task': 'celery_app.tasks.send_daily_stats',
        'schedule': 86400.0,  # Каждые 24 часа (в секундах)
    },
}

@app.task(bind=True)
def debug_task(self):
    print(f'Request: {self.request!r}')

