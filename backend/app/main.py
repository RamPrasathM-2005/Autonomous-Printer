from contextlib import asynccontextmanager
import re
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from fastapi.exceptions import RequestValidationError
from cryptography.fernet import Fernet
from app.config.settings import settings
from app.config.database import engine
from app.db.base import Base
from app.security_middleware import RequestSecurityMiddleware
from app.utils.errors import AppException, app_exception_handler, validation_exception_handler, general_exception_handler
from app.api.routes import documents, print_servers, orders, payments, agent, maintenance, sessions

@asynccontextmanager
async def lifespan(app):
    if len(settings.JWT_SECRET_KEY) < 32 or len(settings.OTP_HASH_KEY) < 32:
        raise RuntimeError('Configure independent random JWT_SECRET_KEY and OTP_HASH_KEY (32+ characters).')
    Fernet(settings.OTP_ENCRYPTION_KEY.encode())
    if not re.fullmatch(r'rzp_(test|live)_[A-Za-z0-9]+', settings.RAZORPAY_KEY_ID) or not settings.RAZORPAY_KEY_SECRET:
        raise RuntimeError('Configure genuine Razorpay test or live API credentials.')
    if settings.JWT_SECRET_KEY == settings.OTP_HASH_KEY:
        raise RuntimeError('JWT and OTP hash keys must be independent.')
    if settings.ALLOW_MOCK_PRINTING and not settings.RAZORPAY_KEY_ID.startswith('rzp_test_'):
        raise RuntimeError('Mock printing requires Razorpay test keys; it cannot be enabled for live payments.')
    if settings.ENVIRONMENT == 'production':
        if not settings.ALLOWED_ORIGINS or any(not o.startswith('https://') for o in settings.ALLOWED_ORIGINS):
            raise RuntimeError('Production requires explicit HTTPS browser origins.')
        if len(settings.RAZORPAY_WEBHOOK_SECRET) < 32 or settings.ALLOW_MOCK_PRINTING:
            raise RuntimeError('Production requires webhook credentials and real printing.')
        if not settings.ALLOWED_HOSTS or any('*' in h for h in settings.ALLOWED_HOSTS):
            raise RuntimeError('Production requires explicit hostnames.')
    # Schema changes are explicit: python -m app.db.migrate before starting services.
    Base.metadata.create_all(engine)
    yield

app = FastAPI(title=settings.APP_NAME, version='2.0.0', lifespan=lifespan,
              docs_url='/docs' if settings.ENVIRONMENT != 'production' else None,
              redoc_url=None)
app.add_middleware(RequestSecurityMiddleware)
app.add_middleware(CORSMiddleware, allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=False, allow_methods=['GET','POST','DELETE','OPTIONS'],
    allow_headers=['Content-Type','Authorization','Idempotency-Key'])
app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS)
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)
for module in (sessions, documents, print_servers, orders, payments, agent, maintenance):
    app.include_router(module.router)

@app.get('/health')
def health():
    from sqlalchemy import text
    with engine.connect() as connection:
        connection.execute(text('SELECT 1'))
    return {'status': 'healthy', 'app': settings.APP_NAME, 'environment': settings.ENVIRONMENT,
            'paymentMode': 'test' if settings.RAZORPAY_KEY_ID.startswith('rzp_test_') else 'live',
            'mockPrinting': settings.ALLOW_MOCK_PRINTING}
