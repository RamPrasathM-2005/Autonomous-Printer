import logging
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

from app.config.settings import settings

logger = logging.getLogger(__name__)

class EmailService:
    @staticmethod
    def send_otp(email: str, otp: str, purpose: str = "login") -> bool:
        """
        Dispatches OTP code to the given email address using Gmail SMTP or configured provider.
        """
        clean_email = email.strip().lower()
        provider = (settings.EMAIL_PROVIDER or "smtp").lower().strip()

        if provider == "smtp":
            return EmailService._send_smtp(clean_email, otp, purpose)
        else:
            # Mock / console logger
            logger.info(f"[EMAIL MOCK] To: {clean_email} | Code: {otp} | Purpose: {purpose}")
            print(f"\n=======================================================", flush=True)
            print(f"[ACHUPPORI EMAIL OTP] Email: {clean_email} | Code: {otp} | Purpose: {purpose}", flush=True)
            print(f"=======================================================\n", flush=True)
            return True

    @staticmethod
    def _send_smtp(to_email: str, otp: str, purpose: str = "login") -> bool:
        smtp_user = settings.SMTP_USER.strip()
        smtp_password = settings.SMTP_PASSWORD.replace(" ", "").strip()
        smtp_host = settings.SMTP_HOST.strip() or "smtp.gmail.com"
        smtp_port = int(settings.SMTP_PORT or 587)
        from_email = settings.SMTP_FROM_EMAIL.strip() or smtp_user
        from_name = settings.SMTP_FROM_NAME.strip() or "Achuppori Cloud Print"

        if not (smtp_user and smtp_password):
            logger.warning("[EMAIL] SMTP credentials incomplete; verification email was not sent.")
            return False

        subject = f"Your Achuppori Verification Code: {otp}"
        action_text = "register your student account" if purpose == "signup" else "sign in to your student account"

        # Plain text version
        text_content = (
            f"Achuppori Cloud Print Verification\n\n"
            f"Your one-time verification code is: {otp}\n\n"
            f"Use this code to {action_text}. This code will expire in 5 minutes.\n"
            f"If you did not request this verification code, please ignore this email.\n\n"
            f"-- Achuppori Support"
        )

        # Responsive HTML version
        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verification Code</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #F8FAFC; padding: 30px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 500px; background-color: #FFFFFF; border-radius: 16px; border: 1px solid #E2E8F0; overflow: hidden; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.04);">
          <!-- Header -->
          <tr>
            <td style="background-color: #2563EB; padding: 24px 30px; text-align: center;">
              <h1 style="margin: 0; color: #FFFFFF; font-size: 20px; font-weight: 700; letter-spacing: 0.5px;">Achuppori Cloud Print</h1>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding: 30px;">
              <h2 style="margin: 0 0 12px 0; color: #0F172A; font-size: 18px; font-weight: 600;">Verification Code</h2>
              <p style="margin: 0 0 20px 0; color: #475569; font-size: 14px; line-height: 1.5;">
                Use the one-time code below to {action_text}:
              </p>
              
              <!-- OTP Box -->
              <div style="background-color: #EFF6FF; border: 1.5px dashed #3B82F6; border-radius: 12px; padding: 18px; text-align: center; margin-bottom: 24px;">
                <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #1D4ED8; font-family: monospace;">{otp}</span>
              </div>

              <p style="margin: 0 0 8px 0; color: #64748B; font-size: 13px;">
                • Code expires in <strong>5 minutes</strong>.
              </p>
              <p style="margin: 0 0 24px 0; color: #64748B; font-size: 13px;">
                • Never share this code with anyone.
              </p>

              <hr style="border: none; border-top: 1px solid #E2E8F0; margin: 20px 0;">

              <p style="margin: 0; color: #94A3B8; font-size: 12px; line-height: 1.4;">
                If you did not request this verification code, you can safely disregard this email.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; padding: 16px 30px; text-align: center; border-top: 1px solid #E2E8F0;">
              <p style="margin: 0; color: #94A3B8; font-size: 11px;">
                © {settings.APP_NAME} Cloud Print Platform. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{from_name} <{from_email}>"
        msg["To"] = to_email

        part1 = MIMEText(text_content, "plain", "utf-8")
        part2 = MIMEText(html_content, "html", "utf-8")
        msg.attach(part1)
        msg.attach(part2)

        try:
            context = ssl.create_default_context()
            with smtplib.SMTP(smtp_host, smtp_port, timeout=12.0) as server:
                server.ehlo()
                server.starttls(context=context)
                server.ehlo()
                server.login(smtp_user, smtp_password)
                server.sendmail(from_email, [to_email], msg.as_string())
            logger.info(f"[EMAIL] Verification code successfully sent to {to_email}")
            return True
        except Exception as e:
            logger.exception(f"[EMAIL] Failed to send OTP to {to_email} via SMTP: {e}")
            return False

email_service = EmailService()
