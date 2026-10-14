# Deploy Achuppori at https://erp.nec.edu.in/achuppori/

This runbook is based on the current source. The college server, its web-server configuration, TLS, MySQL version, SMTP, payment account, and physical printer have not been inspected or tested here. Run Ubuntu commands in the remote Ubuntu terminal opened through AnyDesk, except where marked laptop or Pi. Do not share AnyDesk credentials, database passwords, or `.env` contents in chat.

## 1. Understand what runs where

`/achuppori/` is a URL path, not a query parameter. DNS sends `erp.nec.edu.in` to the college's public entry point. The existing HTTPS web server decides which application receives each URL.

| Request | Destination in this plan |
| --- | --- |
| `/ims/` | Existing IMS configuration, unchanged |
| `/achuppori/` | Compiled Flutter web files |
| `/achuppori/api/orders/...` | Python API at `127.0.0.1:8010/api/orders/...` |
| `/achuppori/health` | Python API at `127.0.0.1:8010/health` |

For IMS, `pm2 restart 2` restarts whichever process currently has PM2 ID 2. It does not define `/ims`. That routing is normally configured in Nginx, Apache, an upstream proxy, or the application's static-file handling. The exact IMS arrangement must be inspected. A folder called `ims` alone does not prove the routing configuration.

Achuppori has a Flutter frontend, FastAPI Python backend, Python reconciliation/cleanup worker, MySQL database, private document storage, and a separate Python print agent on the Pi. Node is not the backend runtime. `npm run build` is not its frontend build command.

```text
Student browser -- HTTPS --> existing ERP web server
                              |-- /ims/ --> existing IMS
                              |-- /achuppori/ --> static Flutter build
                              `-- /achuppori/api/ --> Python API :8010
                                                         |-- MySQL
                                                         |-- private document storage
                                                         |-- SMTP / Razorpay
                                                         `-- worker shares DB and storage

Pi -- outbound HTTPS --> /achuppori/api/ (heartbeat, job polling,
                                           document download, status updates)
Pi -- local CUPS --> physical printer
Pi browser -- localhost:5001 --> local kiosk
```

The server does not initiate a connection to the Pi. The Pi can be on another VLAN or another internet connection if it can resolve and reach the public HTTPS domain. No Pi public IP, tunnel, or inbound forwarding of ports 5001/631 is required. Internet access must actually work from the Pi; campus NAT loopback, captive portals, DNS, proxies, and firewall rules can affect that.

## 2. First visit: inspect only

Open AnyDesk, connect to the Ubuntu desktop, and open Terminal. These are read-only checks:

```bash
whoami
pwd
cat /etc/os-release
python3 --version
command -v flutter
df -h
free -h
sudo ss -ltnp
systemctl status nginx apache2 mysql mariadb --no-pager
pm2 list
pm2 describe 2
ls -ld /var/www/html/erp.nec.edu.in
```

Some commands may report that a service or executable does not exist. That is useful information. PM2 lists are per Unix user; inspect it as the user who manages IMS, not automatically through `sudo pm2`.

If Nginx is installed:

```bash
sudo nginx -t
sudo nginx -T
```

If Apache is installed:

```bash
sudo apache2ctl configtest
sudo apache2ctl -S
sudo apache2ctl -M
```

Locate routing configuration:

```bash
sudo grep -RInE 'erp\.nec\.edu\.in|/ims|ProxyPass|proxy_pass|DocumentRoot|server_name' /etc/nginx /etc/apache2 2>/dev/null
```

Identify the HTTPS virtual host actually serving ERP, its configuration file, document root, existing catch-all rules, and whether another machine terminates HTTPS. If another proxy fronts this computer, the administrator must route `/achuppori/` through that proxy too. Do not install a competing Nginx/Apache or replace the ERP virtual host.

**Stop before installation if the active HTTPS host, available port 8010, sudo access, backup procedure, or server ownership is unclear.** Keep terminal output private if it includes credentials or internal configuration. You can share redacted OS/version, listening ports, virtual-host mapping, and the relevant routing blocks for a tailored final configuration.

## 3. Back up before changes

Use a new private backup directory for this deployment:

```bash
DEPLOY_BACKUP="/var/backups/achuppori-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 700 "$DEPLOY_BACKUP"
```

For the active web server only:

```bash
# Nginx
sudo cp -a /etc/nginx "$DEPLOY_BACKUP/nginx"
# OR Apache
sudo cp -a /etc/apache2 "$DEPLOY_BACKUP/apache2"
```

Follow the college's existing IMS database/files backup procedure. Do not reset, migrate, or otherwise modify the IMS database. Record the current IMS URL and confirm it works before and after deployment.

## 4. Build the frontend on your laptop

The Ubuntu server does not need Flutter if you upload an already compiled build. Build using your working Flutter SDK on the laptop. The project requires Dart `^3.13.4`; check your installed SDK rather than assuming any Flutter version will work.

**Required source preparation for this checkout:** `frontend/lib/config/api_config.dart` currently loads `/env.json` from the domain root, and an empty runtime URL falls back to the domain root. Before building for the ERP path, change:

```dart
final uri = Uri.parse('/env.json');
```

to:

```dart
final uri = Uri.parse('${defaultBackendUrl}/env.json');
```

Also change:

```dart
final parsed = configured.isEmpty ? Uri.base.origin : normalizeBackendUrl(configured);
```

to:

```dart
final parsed = configured.isEmpty ? defaultBackendUrl : normalizeBackendUrl(configured);
```

This deployment uses the explicit build URL below, so runtime configuration is requested from `/achuppori/env.json`, and the frontend appends `/api/...` to `/achuppori`. These source adjustments are instructions, not edits already made by this runbook. Review and test them before publishing. Do not create or overwrite ERP's root `/env.json` to work around the problem.

Laptop PowerShell, from the project root:

```powershell
Set-Location frontend
flutter --version
flutter pub get --enforce-lockfile
flutter build web --release --base-href /achuppori/ --dart-define=BACKEND_URL=https://erp.nec.edu.in/achuppori --no-web-resources-cdn
Set-Content -LiteralPath build/web/env.json -Encoding ascii -Value '{"BACKEND_URL":"https://erp.nec.edu.in/achuppori"}'
Select-String -Path build/web/index.html -Pattern '<base href='
```

Expect `<base href="/achuppori/">`. Upload the **contents** of `frontend/build/web`, not the `frontend` source folder. Flutter's output is `build/web`, not React's `dist`. The current `run-server.py build` wrapper does not accept `--base-href`; use the direct Flutter command above.

Public `env.json` contains only a public backend URL. Never include API secrets, database credentials, JWT keys, or device tokens.

## 5. Prepare Ubuntu directories and Python

Use these separate locations:

| Path | Purpose |
| --- | --- |
| `/opt/achuppori/backend` | Private Python source and `.env` |
| `/opt/achuppori/.venv` | Ubuntu Python dependencies |
| `/var/lib/achuppori/storage` | Persistent private documents |
| `/var/www/html/erp.nec.edu.in/achuppori` | Public compiled frontend only |

If these paths or the `achuppori` account already exist, inspect the existing deployment before overwriting anything.

The project setup script requires Python 3.12 or newer. On Ubuntu 24.04, the default Python is 3.12. On older Ubuntu, stop and arrange a supported Python 3.12+ installation with the administrator; do not replace Ubuntu's system Python or run an OS upgrade as part of this deployment.

```bash
sudo apt-get update
sudo apt-get install -y python3-venv python3-pip rsync curl ca-certificates
python3 --version
sudo adduser --system --group --home /opt/achuppori achuppori
sudo install -d -o achuppori -g achuppori -m 750 /opt/achuppori/backend
sudo install -d -o achuppori -g achuppori -m 750 /var/lib/achuppori/storage
sudo install -d -m 755 /var/www/html/erp.nec.edu.in/achuppori
```

Through AnyDesk file transfer, upload a clean package to a staging folder in your Ubuntu user's home, for example `~/achuppori-upload`. It should contain `backend/`, `deploy/`, and `web/` (compiled frontend contents). Exclude laptop `.env`, `.venv`, databases, document storage, logs, `.git`, and test payment/customer data. Never transfer a Windows virtual environment to Ubuntu.

```bash
test -f "$HOME/achuppori-upload/backend/requirements.txt"
test -f "$HOME/achuppori-upload/web/index.html"
sudo rsync -a --exclude=.env --exclude=__pycache__ --exclude=storage --exclude='*.db' --exclude='*.db-*' "$HOME/achuppori-upload/backend/" /opt/achuppori/backend/
sudo chown -R achuppori:achuppori /opt/achuppori/backend
sudo -u achuppori python3 -m venv /opt/achuppori/.venv
sudo -u achuppori /opt/achuppori/.venv/bin/python -m pip install -r /opt/achuppori/backend/requirements.txt
sudo rsync -a "$HOME/achuppori-upload/web/" /var/www/html/erp.nec.edu.in/achuppori/
```

Check that the web-server user can traverse the directories and read `index.html`. Do not use `chmod -R 777`.

## 6. Create an independent MySQL database

Use the already installed MySQL/MariaDB after verifying its version and administrator access. Do not reinstall it. The example assumes MySQL and local TCP access. Existing SQLite demonstration data is not automatically transferred to MySQL; plan a separate migration if that data must be preserved.

Generate a database password and JWT secret locally on Ubuntu, then store them privately:

```bash
python3 -c 'import secrets; print(secrets.token_hex(32))'
python3 -c 'import secrets; print(secrets.token_hex(32))'
sudo mysql
```

At the MySQL prompt, replace the password placeholder before running:

```sql
CREATE DATABASE achuppori CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'achuppori_app'@'127.0.0.1' IDENTIFIED BY 'REPLACE_WITH_GENERATED_HEX_PASSWORD';
GRANT ALL PRIVILEGES ON achuppori.* TO 'achuppori_app'@'127.0.0.1';
EXIT;
```

These privileges apply only to the new application database. Current startup creates tables and synchronizes missing columns, so schema permissions are required. Do not grant global privileges or use the MySQL root account in the application. Do not open MySQL port 3306 publicly.

## 7. Configure private backend settings

```bash
sudo -u achuppori cp /opt/achuppori/backend/.env.example /opt/achuppori/backend/.env
sudo chmod 600 /opt/achuppori/backend/.env
sudo -u achuppori nano /opt/achuppori/backend/.env
```

Set real values; this is a template, not ready-to-use credentials:

```dotenv
ENVIRONMENT=production
DATABASE_URL=mysql+pymysql://achuppori_app:GENERATED_HEX_PASSWORD@127.0.0.1:3306/achuppori?charset=utf8mb4
JWT_SECRET_KEY=SEPARATE_GENERATED_SECRET_AT_LEAST_32_CHARACTERS
STORAGE_ROOT=/var/lib/achuppori/storage
ALLOWED_ORIGINS=["https://erp.nec.edu.in"]
ADMIN_EMAIL=REAL_ADMIN_EMAIL
ADMIN_PASSWORD=STRONG_UNIQUE_ADMIN_PASSWORD
ADMIN_NAME=Platform Administrator
EMAIL_PROVIDER=smtp
SMTP_HOST=YOUR_SMTP_HOST
SMTP_PORT=587
SMTP_USER=YOUR_SMTP_USER
SMTP_PASSWORD=YOUR_SMTP_PASSWORD
SMTP_FROM_EMAIL=YOUR_APPROVED_SENDER
SMTP_FROM_NAME=Achuppori Cloud Print
RAZORPAY_KEY_ID=YOUR_KEY_ID
RAZORPAY_KEY_SECRET=YOUR_KEY_SECRET
RAZORPAY_WEBHOOK_SECRET=YOUR_SEPARATE_WEBHOOK_SECRET
```

Use quoted values if a dotenv value contains whitespace or comment characters. With arbitrary database passwords, URL-encode reserved characters in `DATABASE_URL`; generated hex avoids that issue. CORS uses the origin `https://erp.nec.edu.in`, without `/achuppori`.

Start with Razorpay test credentials and test webhooks; enable live payments only after the complete flow works. Configure SMTP credentials before testing student OTP. The administrator is created/synchronized during startup; while `ADMIN_PASSWORD` remains set, restarting can synchronize that account password again.

## 8. Run API and worker with systemd

Use systemd for these Python processes. Leave IMS's PM2 process alone. Do not run the local development launcher in production or add a second copy of the worker under PM2.

Copy the repository units from your uploaded package:

```bash
sudo cp "$HOME/achuppori-upload/deploy/systemd/achuppori-backend.service" /etc/systemd/system/
sudo cp "$HOME/achuppori-upload/deploy/systemd/achuppori-worker.service" /etc/systemd/system/
sudo nano /etc/systemd/system/achuppori-backend.service
```

Change the backend `ExecStart` port from 8000 to **8010**:

```ini
ExecStart=/opt/achuppori/.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8010 --workers 1 --proxy-headers --forwarded-allow-ips=127.0.0.1
```

Keep the other unit settings, including `User=achuppori`, working directory, and environment file. The worker remains `python -m app.worker`, using the same database and storage. Start the API first so schema initialization completes before the worker:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now achuppori-backend
sudo systemctl status achuppori-backend --no-pager
curl -fsS http://127.0.0.1:8010/health
sudo systemctl enable --now achuppori-worker
sudo systemctl status achuppori-worker --no-pager
sudo journalctl -u achuppori-backend -u achuppori-worker -n 80 --no-pager
```

Stop here if the API fails or the worker keeps restarting. `/health` confirms API startup, not successful payment, email, printer output, or continued database health. Keep one API worker and one reconciliation worker for this initial deployment.

## 9A. If the existing ERP server uses Nginx

Add these locations **inside its existing ERP HTTPS `server { ... }` block**. Do not paste the repository's standalone `deploy/nginx/achuppori.conf` over ERP: it defines a different hostname/root and uses port 8000.

```nginx
location = /achuppori {
    return 301 /achuppori/$is_args$args;
}

location = /achuppori/health {
    proxy_pass http://127.0.0.1:8010/health;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location ^~ /achuppori/api/ {
    client_max_body_size 51m;
    proxy_pass http://127.0.0.1:8010/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_read_timeout 120s;
}

location ^~ /achuppori/ {
    root /var/www/html/erp.nec.edu.in;
    index index.html;
    try_files $uri $uri/ /achuppori/index.html;
    # Initial deployment: avoid stale application/config files.
    add_header Cache-Control "no-store" always;
    add_header X-Content-Type-Options "nosniff" always;
}
```

`root` is the parent directory, because Nginx appends `/achuppori/...`. The API mapping deliberately removes only `/achuppori`, retaining `/api/`. Nginx replaces a matched location prefix when `proxy_pass` contains a URI. See the [official proxy documentation](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass).

Inspect existing server-level rewrites, location conflicts, security headers, and CSP before activation. A restrictive inherited CSP can block Flutter or Razorpay. Do not change shared ERP headers blindly; scope any necessary adjustments to Achuppori after browser testing. Keep existing TLS certificates and redirects.

```bash
sudo nginx -t
```

Only if that succeeds:

```bash
sudo systemctl reload nginx
```

## 9B. If the existing ERP server uses Apache

Use this branch instead of 9A. Check required modules:

```bash
sudo apache2ctl -M
```

If missing, enable the necessary modules with the administrator:

```bash
sudo a2enmod proxy proxy_http alias rewrite headers
```

Inside the existing ERP HTTPS `<VirtualHost ...:443>` block, add the following **before broad `ProxyPass / ...` mappings**:

```apache
ProxyPass "/achuppori/api/" "http://127.0.0.1:8010/api/" timeout=120
ProxyPassReverse "/achuppori/api/" "http://127.0.0.1:8010/api/"
ProxyPassMatch "^/achuppori/health$" "http://127.0.0.1:8010/health"
ProxyPassReverse "/achuppori/health" "http://127.0.0.1:8010/health"
ProxyPass "/achuppori/" "!"

RewriteEngine On
RewriteRule ^/?achuppori$ /achuppori/ [R=301,L]

Alias "/achuppori/" "/var/www/html/erp.nec.edu.in/achuppori/"
<Directory "/var/www/html/erp.nec.edu.in/achuppori">
    Require all granted
    AllowOverride None
    Options -Indexes -MultiViews
    DirectoryIndex index.html
    FallbackResource /achuppori/index.html
    Header always set Cache-Control "no-store"
</Directory>
<Location "/achuppori/api/">
    LimitRequestBody 53477376
    RequestHeader set X-Forwarded-Proto "https"
</Location>
```

This example assumes Apache itself handles public HTTPS. If TLS ends at another proxy, forwarding rules require adjustment. Existing broad rewrite rules may need an Achuppori exclusion placed before them; decide that from the actual host configuration. Apache evaluates proxy mappings in order. See the [official ProxyPass documentation](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass).

```bash
sudo apache2ctl configtest
```

Only if that succeeds:

```bash
sudo systemctl reload apache2
```

## 10. Validate public routing before payments

On Ubuntu and again from the laptop:

```bash
curl -I https://erp.nec.edu.in/ims/
curl -I https://erp.nec.edu.in/achuppori
curl -I https://erp.nec.edu.in/achuppori/
curl -fsS https://erp.nec.edu.in/achuppori/env.json
curl -fsS https://erp.nec.edu.in/achuppori/health
```

Use HTTPS without `curl -k`. The missing slash should redirect; `env.json` must return JSON and health must return the backend's JSON, not Flutter HTML. Test from mobile data as well as campus Wi-Fi to confirm real public access.

Open a private browser window at `https://erp.nec.edu.in/achuppori/`. In Developer Tools → Network, verify JavaScript/assets load under `/achuppori/`, requests go to `/achuppori/api/...`, and there are no requests to root `/api/` or `/env.json`. Check login, refresh, student OTP, document upload and preview, and admin actions. Confirm IMS still works.

Public API port 8010 is unnecessary: verify `ss` shows it bound only to `127.0.0.1`. Do not change UFW rules blindly on the shared server or expose Python, MySQL, CUPS, or local agent ports.

## 11. Configure Razorpay webhook

In the appropriate Razorpay test/live dashboard, configure:

```text
https://erp.nec.edu.in/achuppori/api/payments/webhook
```

Use the matching `RAZORPAY_WEBHOOK_SECRET`. The current handler recognizes `payment.captured` and `order.paid`. Test dashboard delivery and verify the database/order result; a browser checkout success alone is insufficient. Never mix test and live credentials. Confirm institutional approval, account ownership, refund permissions, and real transaction verification before opening paid printing to students.

## 12. Connect the existing Pi print agent

Register the station in the public admin application first. Copy its exact station ID and unique device token privately. Existing local demonstration credentials will not magically exist in the new MySQL database.

On the Pi, first check access:

```bash
date
getent hosts erp.nec.edu.in
curl -fsS --max-time 15 https://erp.nec.edu.in/achuppori/health
lpstat -p -d
```

If public access fails from the Pi, resolve campus DNS/firewall/NAT routing with the administrator. Keep HTTPS verification enabled. Correct the Pi's clock if certificate validation fails.

Back up the existing Pi `.env` privately, then edit `print-agent/.env` in the existing installation:

```dotenv
AGENT_ID=EXACT_REGISTERED_STATION_ID
AGENT_TOKEN=EXACT_UNIQUE_DEVICE_TOKEN
BACKEND_URL=https://erp.nec.edu.in/achuppori/api
KIOSK_WEB_URL=https://erp.nec.edu.in/achuppori/
MOCK_CUPS=false
CUPS_SERVER=localhost
PRINTER_NAME=
HOST=127.0.0.1
PORT=5001
STORAGE_ROOT=./storage
LOG_DIR=./logs
```

The agent's `BACKEND_URL` includes `/api`; the frontend's configured backend URL does not. Keep station tokens on the Pi and server, never in Flutter's build.

For an already installed service, during an agreed maintenance window with no active print job:

```bash
sudo systemctl restart print-agent
sudo systemctl status print-agent --no-pager
sudo journalctl -u print-agent -n 80 --no-pager
curl -fsS http://127.0.0.1:5001/health
```

For a new Pi installation, upload `print-agent/` to a private path without spaces, configure `.env`, then from the project root run:

```bash
sudo bash print-agent/scripts/deploy.sh "$(id -un)"
```

This installer installs CUPS/dependencies, configures systemd, and may update kiosk autostart. Use it for a new installation or deliberate repair, not merely to change the public backend URL. Keep the local kiosk at its existing local agent address; `KIOSK_WEB_URL` changes the public student/QR link. Confirm the QR includes `/achuppori/` and the correct station. Keep the registered CUPS queue name identical to the Pi's real queue.

Do not restart the visible kiosk during a live demonstration or printing session. Schedule it and verify the physical screen afterward. If internet or the server is unavailable, polling and new job release cannot complete; do not promise offline paid printing.

## 13. Required acceptance test

Before public use, demonstrate all of these with a small document:

1. ERP and IMS remain usable.
2. Achuppori opens from campus Wi-Fi and mobile data; refresh and assets work.
3. Student receives a real SMTP OTP and signs in.
4. Admin station shows online with its actual queues.
5. A document uploads, previews, and produces the expected price.
6. A test payment settles; its signed webhook reaches the backend.
7. The student releases the job through the station's intended kiosk/OTP flow.
8. Pi downloads the correct document, the real printer outputs it once, and the job status updates correctly.
9. Offline/unavailable station behavior, failed payment, cancellation, refund handling, and retry behavior are checked without charging real students.
10. Backend and worker survive a planned restart. Pi service and kiosk recover after a planned Pi reboot.
11. Database and private documents can be restored from a verified backup.

Only then perform an approved small live transaction and verify provider capture, output, and settlement. A health response or a mocked print is not physical printer/payment proof.

## 14. Daily control and troubleshooting

```bash
sudo systemctl status achuppori-backend achuppori-worker --no-pager
sudo journalctl -u achuppori-backend -n 100 --no-pager
sudo journalctl -u achuppori-worker -n 100 --no-pager
sudo journalctl -u achuppori-backend -f
```

Restart after backend/config changes:

```bash
sudo systemctl restart achuppori-backend
curl -fsS http://127.0.0.1:8010/health
sudo systemctl restart achuppori-worker
```

| Symptom | First checks |
| --- | --- |
| 502 | API service/logs; upstream must be 8010 |
| Flutter blank page | Base href, assets, CSP, console, build SDK |
| API returns HTML | Missing proxy mapping or rewrite/catch-all conflict |
| Calls go to root `/api` | Build URL and runtime `env.json` source preparation |
| Upload 413 | Web-server limit and backend 50 MB document limit |
| Login OTP absent | SMTP credentials, outbound SMTP access, logs |
| Station offline | Pi network, public URL, device ID/token, heartbeat logs |
| Printer missing | Pi CUPS queue and admin queue assignment |
| Payment not reconciled | Signed webhook, matching provider keys, worker logs |

Do not log or share document contents, passwords, tokens, or full environment files while diagnosing problems.

## 15. Updates, backup, and rollback

Frontend updates: build on the laptop with the same base href and backend URL, upload to a new staging directory, retain the previous published build, and replace only Achuppori's public files. Prefer versioned web directories and an atomic symlink switch once the administrator has established that layout. No API restart is needed for static-file changes. Do not delete IMS files or the ERP document root.

Backend updates: schedule maintenance, stop accepting new jobs, allow active physical prints to finish, back up code/config, database, and storage, then stop the worker and API before replacing application files. Preserve `.env`, persistent storage, and database. Install updated dependencies into the Ubuntu virtual environment, start API, check it, then start worker. Never upload development databases into production.

Before first startup after an upgrade, remember that this API automatically creates/synchronizes schema. Code rollback alone does not undo schema or data changes.

For a consistent application backup, stop application writes during maintenance:

```bash
sudo systemctl stop achuppori-worker achuppori-backend
```

Create a fresh root-only backup directory as in section 3, then use the college's database backup account. Example using root's local MySQL authentication:

```bash
sudo sh -c 'umask 077; mysqldump --single-transaction --no-tablespaces achuppori > "$1/achuppori.sql"' sh "$DEPLOY_BACKUP"
sudo cp -a /var/lib/achuppori/storage "$DEPLOY_BACKUP/storage"
sudo cp -a /opt/achuppori/backend "$DEPLOY_BACKUP/backend"
sudo cp -a /var/www/html/erp.nec.edu.in/achuppori "$DEPLOY_BACKUP/web"
sudo cp -a /etc/systemd/system/achuppori-backend.service /etc/systemd/system/achuppori-worker.service "$DEPLOY_BACKUP/"
```

Do not put a database password on the command line. If root socket authentication is unavailable, arrange a protected MySQL option file or approved backup tool. Verify backup files and a restoration rehearsal; keep encrypted off-server copies with controlled access and an approved document-retention policy. Start API, confirm health, then start worker after the backup.

If routing breaks, restore the backed-up active virtual-host configuration, validate it, and reload the existing web server. If application deployment breaks, stop the new services and restore the previous code/build/config. Database restoration requires an explicit maintenance decision because restoring an older snapshot can discard newer payments/orders. Never restore an old payment database casually while provider transactions continue.

## References

- [Flutter subpath/base href guidance](https://docs.flutter.dev/ui/navigation/url-strategies)
- [Nginx proxy URI mapping](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass)
- [Nginx static-file routing](https://docs.nginx.com/nginx/admin-guide/web-server/serving-static-content/)
- [Apache reverse proxy configuration](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass)

The first action on the college computer is section 2. The exact active virtual-host file and its existing rewrites determine which configuration branch is suitable.
