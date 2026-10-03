import logging
from typing import Optional
import httpx
from app.config.settings import settings

logger = logging.getLogger(__name__)

class SmsService:
    @staticmethod
    def send_otp(phone: str, otp: str) -> bool:
        """
        Dispatches OTP code to the given phone number using configured SMS_PROVIDER.
        Supported providers:
          - "mock": logs the code to server console (default for development/staging)
          - "fast2sms": popular Indian SMS gateway for quick transactional OTPs
          - "twilio": international SMS service
        """
        clean_phone = phone.strip().replace(" ", "").replace("-", "")
        message = f"Your Achuppori verification code is {otp}. Valid for 5 minutes. Do not share this code."
        provider = (settings.SMS_PROVIDER or "mock").lower().strip()

        if provider == "fast2sms":
            return SmsService._send_fast2sms(clean_phone, otp)
        elif provider == "twilio":
            return SmsService._send_twilio(clean_phone, message)
        else:
            # Default: mock / logging
            logger.info(f"[SMS MOCK] To: {clean_phone} | Code: {otp} | Message: {message}")
            print(f"\n=======================================================")
            print(f"[ACHUPPORI SMS OTP] Phone: {clean_phone} | Code: {otp}")
            print(f"=======================================================\n")
            return True

    @staticmethod
    def _send_fast2sms(phone: str, otp: str) -> bool:
        if not settings.FAST2SMS_API_KEY:
            logger.warning("[SMS] FAST2SMS_API_KEY is not configured. Falling back to console log.")
            print(f"[ACHUPPORI SMS OTP FALLBACK] Phone: {phone} | Code: {otp}")
            return True

        # Extract 10-digit mobile number for Fast2SMS
        numbers = phone[-10:]
        url = "https://www.fast2sms.com/dev/bulkV2"
        headers = {
            "authorization": settings.FAST2SMS_API_KEY,
            "Content-Type": "application/json"
        }
        payload = {
            "route": "otp",
            "variables_values": otp,
            "numbers": numbers
        }

        try:
            with httpx.Client(timeout=8.0) as client:
                resp = client.post(url, json=payload, headers=headers)
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("return") is True:
                        logger.info(f"[SMS] Fast2SMS OTP delivered to {numbers}")
                        return True
                    else:
                        logger.error(f"[SMS] Fast2SMS error response: {data}")
                else:
                    logger.error(f"[SMS] Fast2SMS HTTP error: {resp.status_code} - {resp.text}")
        except Exception as e:
            logger.exception(f"[SMS] Failed to send OTP via Fast2SMS: {e}")

        return False

    @staticmethod
    def _send_twilio(phone: str, message: str) -> bool:
        if not (settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN and settings.TWILIO_FROM_PHONE):
            logger.warning("[SMS] Twilio credentials incomplete. Falling back to console log.")
            print(f"[ACHUPPORI SMS OTP FALLBACK] Phone: {phone} | Message: {message}")
            return True

        # Ensure E.164 phone formatting
        target_phone = phone if phone.startswith("+") else f"+91{phone[-10:]}"
        url = f"https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Messages.json"
        data = {
            "To": target_phone,
            "From": settings.TWILIO_FROM_PHONE,
            "Body": message
        }

        try:
            with httpx.Client(timeout=8.0) as client:
                resp = client.post(
                    url,
                    data=data,
                    auth=(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
                )
                if resp.status_code in (200, 201):
                    logger.info(f"[SMS] Twilio OTP sent to {target_phone}")
                    return True
                else:
                    logger.error(f"[SMS] Twilio HTTP error: {resp.status_code} - {resp.text}")
        except Exception as e:
            logger.exception(f"[SMS] Failed to send OTP via Twilio: {e}")

        return False

sms_service = SmsService()
