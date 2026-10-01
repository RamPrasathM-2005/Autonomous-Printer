"""Create, test and drop a uniquely named disposable MySQL database. No app tables touched."""
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid
from dotenv import dotenv_values
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

root = Path(__file__).resolve().parents[1]
url = make_url(dotenv_values(root / 'backend' / '.env')['DATABASE_URL'])
if url.get_backend_name() != 'mysql':
    raise SystemExit('This test runner requires MySQL.')
name = 'printer_security_test_' + uuid.uuid4().hex[:12]
admin = create_engine(url.set(database=None))
created = False
try:
    with admin.begin() as connection:
        connection.execute(text('CREATE DATABASE ' + name + ' CHARACTER SET utf8mb4'))
        created = True
    env = os.environ.copy()
    env['MYSQL_SECURITY_TEST_URL'] = url.set(database=name).render_as_string(hide_password=False)
    result = subprocess.run([sys.executable, '-m', 'pytest', 'tests/test_mysql_concurrency.py',
                             '-q', '--tb=short'], cwd=root / 'backend', env=env)
finally:
    if created:
        assert re.fullmatch(r'printer_security_test_[a-f0-9]{12}', name)
        assert name != url.database
        with admin.begin() as connection:
            connection.execute(text('DROP DATABASE ' + name))
    admin.dispose()
sys.exit(result.returncode)
