"""Physical device observations, bounded separately from CUPS queue state."""
import socket
import threading
import time
from urllib.parse import urlsplit

_cache = {}
_lock = threading.Lock()


def reachable(uri, force=False):
    parts = urlsplit(str(uri or ''))
    if parts.scheme not in ('ipp', 'ipps', 'socket', 'lpd'):
        return None
    try:
        host = parts.hostname
        port = parts.port or {'ipp': 631, 'ipps': 631, 'socket': 9100, 'lpd': 515}[parts.scheme]
        if not host:
            return False
    except ValueError:
        return False
    now = time.monotonic()
    with _lock:
        previous = _cache.get(uri)
        if not force and previous and now - previous[0] < 5:
            return previous[1]
    try:
        with socket.create_connection((host, port), timeout=1.5):
            result = True
    except OSError:
        result = False
    with _lock:
        if len(_cache) >= 128:
            _cache.clear()
        _cache[uri] = (now, result)
    return result


def observe(info, force=False):
    uri = info.get('device-uri', '')
    if reachable(uri, force) is False:
        return 'OFFLINE', 'Printer offline. Reconnect or turn on the printer.'
    reasons = ' '.join(str(x).lower() for x in info.get('printer-state-reasons', []))
    message = str(info.get('printer-state-message') or '').lower()
    text = reasons + ' ' + message
    if any(x in text for x in ('offline', 'unreachable', 'unable to connect', 'not responding', 'may not exist', 'connecting-to-device')):
        return 'OFFLINE', 'Printer offline. Reconnect or turn on the printer.'
    if any(x in text for x in ('media-empty', 'media-needed', 'out of paper', 'load paper')):
        return 'OUT_OF_PAPER', 'Load paper to continue printing.'
    if any(x in text for x in ('media-jam', 'paper jam', 'door-open', 'cover-open', 'toner-empty', 'filter failed')):
        return 'ERROR', 'Printer needs attention. Check paper, covers and toner.'
    if info.get('printer-state') == 5 or info.get('printer-is-accepting-jobs') is False:
        return 'STOPPED', 'Printer queue paused. Ask the attendant to resume it.'
    return ('BUSY' if info.get('printer-state') == 4 else 'READY'), None
