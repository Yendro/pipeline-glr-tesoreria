import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email.mime.image import MIMEImage
from email import encoders
from pathlib import Path
from typing import List
from src.config import (
    EMAIL_SERVER, EMAIL_PORT, EMAIL_USER, EMAIL_PASSWORD,
    EMAIL_RECIPIENTS, EMAIL_CC, EMAIL_SUBJECT, EMAIL_BODY,
    EMAIL_LOGO_PATH, EMAIL_SIGNATURE_PATH
)

logger = logging.getLogger(__name__)

def enviar_correo(archivos_adjuntos: List[Path]) -> bool:
    """
    Envía un correo electrónico con los archivos adjuntos.

    Args:
        archivos_adjuntos: Lista de rutas a los archivos a adjuntar.

    Returns:
        bool: True si el envío fue exitoso, False en caso contrario.
    """
    if not EMAIL_USER or not EMAIL_PASSWORD:
        logger.error("Credenciales de correo no configuradas en el entorno")
        return False

    # Configurar el mensaje
    msg = MIMEMultipart('mixed')

    msg['From'] = EMAIL_USER
    msg['To'] = ", ".join(EMAIL_RECIPIENTS)
    msg['Cc'] = ", ".join(EMAIL_CC)
    msg['Subject'] = EMAIL_SUBJECT

    # Contenedor para HTML + imágenes
    msg_related = MIMEMultipart('related')
    msg.attach(msg_related)

    # Contenedor alternativo (texto plano + HTML)
    msg_alternative = MIMEMultipart('alternative')
    msg_related.attach(msg_alternative)

    # Cuerpo HTML
    with open(EMAIL_SIGNATURE_PATH, "r", encoding="utf-8") as f:
        firma_html = f.read()

    html = f"""
        <html>
        <body>
            <p>{EMAIL_BODY}</p>
            {firma_html}
        </body>
        </html>
        """
    parte_html = MIMEText(html, 'html', 'utf-8')
    msg_alternative.attach(parte_html)

    # Adjuntar imagen (logo) como recurso embebido
    if EMAIL_LOGO_PATH:
        logo_path = Path(EMAIL_LOGO_PATH)
        if logo_path.exists():
            try:
                with open(logo_path, 'rb') as f:
                    logo_data = f.read()
                img = MIMEImage(logo_data)
                img.add_header('Content-ID', '<logo_id>')
                img.add_header('Content-Disposition', 'inline', filename='logo.png')
                msg_related.attach(img)
                logger.info(f"Logo adjuntado: {logo_path}")
            except Exception as e:
                logger.error(f"No se pudo adjuntar el logo: {e}")
        else:
            logger.warning(f"Logo no encontrado: {logo_path}")

    # Adjuntar archivos
    for archivo in archivos_adjuntos:
        if not archivo.exists():
            logger.warning(f"Archivo no encontrado: {archivo}")
            continue
        try:
            with open(archivo, "rb") as adjunto:
                parte = MIMEBase('application', 'octet-stream')
                parte.set_payload(adjunto.read())
                encoders.encode_base64(parte)
                parte.add_header(
                    'Content-Disposition',
                    f'attachment; filename="{archivo.name}"'
                )
                msg.attach(parte)
        except Exception as e:
            logger.error(f"Error adjuntando {archivo.name}: {e}")
            return False

    # Enviar el correo
    try:
        with smtplib.SMTP(EMAIL_SERVER, EMAIL_PORT) as server:
            server.starttls()
            server.login(EMAIL_USER, EMAIL_PASSWORD)
            server.send_message(msg)
        logger.info(f"Correo enviado a: {msg['To']}")
        if msg['Cc']:
            logger.info(f"CC: {msg['Cc']}")
        return True
    except Exception as e:
        logger.error(f"Error al enviar el correo: {e}")
        return False