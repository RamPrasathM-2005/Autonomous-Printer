"""Discover advertised IPP devices on the Pi; provision only admin-mapped queues."""
import hashlib
import re
import socket
import subprocess
import threading
import time
from urllib.parse import urlsplit, urlunsplit
from app.utils.logging import agent_logger


class PrinterDiscovery:
    def __init__(self):
        self.devices = []
        self.last_scan = 0
        self.lock = threading.Lock()
        self.attempts = {}

    def scan(self):
        with self.lock:
            if time.monotonic() - self.last_scan < 30:
                return list(self.devices)
            self.last_scan = time.monotonic()
            try:
                result = subprocess.run(['ippfind', '-T', '3', '--exec', '/usr/bin/printf',
                                         '%s\t%s\n', '{service_name}', '{service_uri}', ';'],
                                        capture_output=True, text=True, timeout=6)
                devices = []
                for line in result.stdout.splitlines()[:32]:
                    if '\t' not in line:
                        continue
                    name, uri = line.split('\t', 1)
                    parts = urlsplit(uri)
                    if parts.scheme not in ('ipp', 'ipps') or not parts.hostname:
                        continue
                    # Stable IP URI avoids a .local resolver dependency in the worker.
                    try:
                        host = socket.gethostbyname(parts.hostname)
                    except OSError:
                        continue
                    uri = urlunsplit((parts.scheme, host + (':' + str(parts.port) if parts.port and parts.port != 631 else ''), parts.path, '', ''))
                    queue = re.sub(r'[^A-Za-z0-9_-]', '_', name)[:80] + '_' + hashlib.sha256(uri.encode()).hexdigest()[:8]
                    devices.append({'cups_printer_name': queue, 'device_uri': uri,
                                    'ip_address': host, 'status': 'DISCOVERED', 'jobs': 0})
                self.devices = devices
            except (OSError, subprocess.TimeoutExpired):
                agent_logger.warning('Nearby printer discovery unavailable; check ippfind and Avahi on the Pi.')
                self.devices = []
            return list(self.devices)

    def provision(self, assignments, installed):
        advertised = {d['device_uri'] for d in self.devices}
        for item in assignments[:32]:
            name, uri = item.get('cups_printer_name', ''), item.get('device_uri', '')
            if name in installed or uri not in advertised or not re.fullmatch(r'[A-Za-z0-9_-]{1,127}', name):
                continue
            if time.monotonic() - self.attempts.get(name, -60) < 60:
                continue
            self.attempts[name] = time.monotonic()
            try:
                # Unix socket authenticates the local lpadmin group membership;
                # TCP localhost can request a password unavailable to the daemon.
                result = subprocess.run(['/usr/sbin/lpadmin', '-h', '/run/cups/cups.sock', '-p', name, '-E', '-v', uri,
                                         '-m', 'everywhere', '-o', 'printer-is-shared=false'],
                                        capture_output=True, text=True, timeout=15)
                if result.returncode:
                    agent_logger.error('Cannot configure mapped printer %s: %s', name, result.stderr.strip())
                else:
                    agent_logger.info('Configured mapped printer %s on this Pi', name)
            except (OSError, subprocess.TimeoutExpired):
                agent_logger.exception('Cannot configure mapped printer %s', name)


printer_discovery = PrinterDiscovery()
