import logging
from datetime import timedelta
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from celery import shared_task
from users.models import User
from notes.models import Note

logger = logging.getLogger('celery')


@shared_task
def send_daily_stats():
    yesterday = timezone.now() - timedelta(days=1)
    users = User.objects.filter(is_active=True)

    for user in users:
        try:
            notes_count = Note.objects.filter(
                user=user,
                created_at__gte=yesterday
            ).count()

            if notes_count > 0:
                subject = 'Ежедневная статистика - Личный Сейф для Заметок'
                message = (
                    f'Здравствуйте, {user.username}!\n\n'
                    f'За последние 24 часа вы создали {notes_count} заметок.\n\n'
                    f'Продолжайте в том же духе!\n\n'
                    f'С уважением,\n'
                    f'Команда Notes Vault'
                )

                send_mail(
                    subject=subject,
                    message=message,
                    from_email=settings.EMAIL_HOST_USER or 'noreply@notesvault.com',
                    recipient_list=[user.email],
                    fail_silently=False,
                )

                logger.info(f'Статистика отправлена пользователю {user.email}: {notes_count} заметок')
            else:
                logger.info(f'Пользователь {user.email} не создал заметок за последние 24 часа')

        except Exception as e:
            logger.error(f'Ошибка отправки статистики пользователю {user.email}: {e}')

    logger.info(f'Задача send_daily_stats завершена в {timezone.now()}')
