"""Bound request bodies before multipart/JSON parsing and reject untrusted browser origins."""
from tempfile import SpooledTemporaryFile
from starlette.responses import JSONResponse
from app.config.settings import settings

class RequestSecurityMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        headers = dict(scope['headers'])
        origin = headers.get(b'origin', b'').decode('latin1')
        if origin and origin not in settings.ALLOWED_ORIGINS:
            return await JSONResponse({'error': 'ORIGIN_DENIED', 'message': 'Origin not allowed.'}, 403)(scope, receive, send)
        async def secure_send(message):
            if message['type'] == 'http.response.start':
                message['headers'] += [(b'cache-control', b'no-store'),
                    (b'x-content-type-options', b'nosniff'), (b'referrer-policy', b'no-referrer'),
                    (b'x-frame-options', b'DENY')]
                if settings.ENVIRONMENT == 'production':
                    message['headers'].append((b'strict-transport-security', b'max-age=31536000; includeSubDomains'))
            await send(message)
        if scope['method'] not in ('POST', 'PUT', 'PATCH'):
            return await self.app(scope, receive, secure_send)
        maximum = ((settings.MAX_UPLOAD_MB + 1) * 1024 * 1024
                   if scope['path'] == '/api/documents/upload' else 256 * 1024)
        try:
            length = int(headers.get(b'content-length', b'0'))
            if length < 0: raise ValueError()
        except ValueError:
            return await JSONResponse({'error': 'INVALID_LENGTH'}, 400)(scope, receive, send)
        if length > maximum:
            return await JSONResponse({'error': 'BODY_TOO_LARGE', 'message': 'Request too large.'}, 413)(scope, receive, send)
        # Spool to disk instead of duplicating a 50 MB upload in every API worker's memory.
        with SpooledTemporaryFile(max_size=1024 * 1024) as body:
            size = 0
            while True:
                message = await receive()
                if message['type'] == 'http.disconnect': return
                chunk = message.get('body', b'')
                size += len(chunk)
                if size > maximum:
                    return await JSONResponse({'error': 'BODY_TOO_LARGE', 'message': 'Request too large.'}, 413)(scope, receive, send)
                body.write(chunk)
                if not message.get('more_body', False): break
            body.seek(0)
            consumed = False
            async def bounded_receive():
                nonlocal consumed
                if consumed:
                    return await receive()
                chunk = body.read(65536)
                more = body.tell() < size
                consumed = not more
                return {'type': 'http.request', 'body': chunk, 'more_body': more}
            await self.app(scope, bounded_receive, secure_send)
