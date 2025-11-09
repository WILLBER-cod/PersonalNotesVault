import os
import logging
from cryptography.fernet import Fernet

logger = logging.getLogger('notes')

ENCRYPTION_KEY = os.getenv('ENCRYPTION_KEY', '').encode()


def get_fernet():
    if not ENCRYPTION_KEY:
        raise ValueError('ENCRYPTION_KEY не установлен в переменных окружения')
    try:
        return Fernet(ENCRYPTION_KEY)
    except Exception as e:
        logger.error(f'Ошибка инициализации Fernet: {e}')
        raise


def encrypt_text(text: str) -> str:
    if not text:
        return ''
    try:
        f = get_fernet()
        encrypted_data = f.encrypt(text.encode('utf-8'))
        return encrypted_data.decode('utf-8')
    except Exception as e:
        logger.error(f'Ошибка шифрования: {e}')
        raise


def decrypt_text(encrypted_text: str) -> str:
    if not encrypted_text:
        return ''
    try:
        f = get_fernet()
        decrypted_data = f.decrypt(encrypted_text.encode('utf-8'))
        return decrypted_data.decode('utf-8')
    except Exception as e:
        logger.error(f'Ошибка расшифровки: {e}')
        raise


def encrypt_note(title: str, content: str) -> tuple[str, str]:
    title_encrypted = encrypt_text(title)
    content_encrypted = encrypt_text(content)
    return title_encrypted, content_encrypted


def decrypt_note(title_encrypted: str, content_encrypted: str) -> tuple[str, str]:
    title = decrypt_text(title_encrypted)
    content = decrypt_text(content_encrypted)
    return title, content
