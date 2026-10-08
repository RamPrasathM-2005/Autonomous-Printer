# Deploy the central server and department Pi

These commands assume Ubuntu 24.04 on the server and Raspberry Pi OS with a desktop on the Pi. Replace `print.example.edu` with your DNS hostname, point DNS to the server and allow ports 80/443. Each machine keeps its own private `.env`.

Publish the reviewed commit to your repository before using the clone commands; otherwise the remote checkout still contains the previous scripts. Existing installations should fetch the updated revision and back up database/uploads before upgrading.

## Server installation

The supplied units expect the checkout at `/opt/achuppori`. Run:

```bash
sudo apt update
sudo apt install -y git python3-venv python3-dev build-essential nginx certbot curl unzip xz-utils libglu1-mesa
sudo useradd --system --create-home --home-dir /var/lib/achuppori --shell /bin/bash achuppori
sudo mkdir -p /opt/achuppori
sudo chown achuppori:achuppori /opt/achuppori
sudo -u achuppori git clone https://github.com/RamPrasathM-2005/Autonomous-Printer.git /opt/achuppori
sudo -u achuppori git clone --depth 1 --branch 3.47.5 https://github.com/flutter/flutter.git /opt/achuppori/flutter-sdk
sudo -u achuppori env PATH=/opt/achuppori/flutter-sdk/bin:$PATH bash -c 'cd /opt/achuppori && python3 run-server.py setup'
sudo chmod 600 /opt/achuppori/backend/.env
sudo -u achuppori nano /opt/achuppori/backend/.env
```

Flutter is needed only for building; copying a tested `frontend/build/web` bundle is an alternative. Configure backend values:

```dotenv
ENVIRONMENT=production
DATABASE_URL=sqlite:////opt/achuppori/backend/print_platform.db
STORAGE_ROOT=/opt/achuppori/backend/storage
JWT_SECRET_KEY=YOUR_RANDOM_SECRET_AT_LEAST_32_CHARACTERS
ALLOWED_ORIGINS=["https://print.example.edu"]
ADMIN_EMAIL=YOUR_ADMIN_EMAIL
ADMIN_PASSWORD=YOUR_ADMIN_PASSWORD_AT_LEAST_12_CHARACTERS
```

Generate the JWT secret with `python3 -c 'import secrets; print(secrets.token_urlsafe(48))'`. Configure all three `RAZORPAY_*` keys and the `SMTP_*` keys from your accounts. Keep frontend `BACKEND_URL=` empty for same-origin hosting. No printer IP, default station or shared central agent token is needed in backend/.env.

For MySQL, provision a dedicated application database/user separately and set `DATABASE_URL=mysql+pymysql://USER:URL_ENCODED_PASSWORD@127.0.0.1:3306/DATABASE`. Reset drops every table in that database. Test migrations and the conflict checker on your actual MySQL instance before using it publicly.

Initialize without deleting data, build and install services:

```bash
sudo -u achuppori mkdir -p /opt/achuppori/backend/storage
sudo -u achuppori bash -c 'cd /opt/achuppori/backend && ../.venv/bin/python -m app.db.migrate && ../.venv/bin/python -m app.db.seed'
sudo -u achuppori /opt/achuppori/.venv/bin/python /opt/achuppori/scripts/check_database.py
sudo -u achuppori env PATH=/opt/achuppori/flutter-sdk/bin:$PATH bash -c 'cd /opt/achuppori && python3 run-server.py build --build'
sudo cp /opt/achuppori/deploy/systemd/achuppori-backend.service /etc/systemd/system/
sudo cp /opt/achuppori/deploy/systemd/achuppori-worker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now achuppori-backend achuppori-worker
curl -f http://127.0.0.1:8000/health
```

For an intentional full reset, back up first, then:

```bash
sudo systemctl stop achuppori-backend achuppori-worker
sudo -u achuppori /opt/achuppori/.venv/bin/python /opt/achuppori/scripts/reset_data.py --yes
sudo systemctl start achuppori-backend achuppori-worker
```

Register departments, stations and printers again after a reset. Clear each Pi's old journal separately as described below.

## Public HTTPS frontend and API

Obtain the certificate before enabling the TLS configuration:

```bash
sudo systemctl stop nginx
sudo certbot certonly --standalone -d print.example.edu
sudo cp /opt/achuppori/deploy/nginx/achuppori.conf /etc/nginx/sites-available/achuppori
sudo nano /etc/nginx/sites-available/achuppori
# Replace every example hostname and certificate path before continuing.
sudo ln -sfn /etc/nginx/sites-available/achuppori /etc/nginx/sites-enabled/achuppori
sudo nginx -t
sudo systemctl start nginx
curl -f https://print.example.edu/health
curl -f https://print.example.edu/env.json
```

For standalone certificate renewal, install pre/post hooks to stop/start Nginx, then verify renewal:

```bash
sudo install -d /etc/letsencrypt/renewal-hooks/pre /etc/letsencrypt/renewal-hooks/post
printf '#!/bin/sh\nsystemctl stop nginx\n' | sudo tee /etc/letsencrypt/renewal-hooks/pre/nginx >/dev/null
printf '#!/bin/sh\nsystemctl start nginx\n' | sudo tee /etc/letsencrypt/renewal-hooks/post/nginx >/dev/null
sudo chmod +x /etc/letsencrypt/renewal-hooks/pre/nginx /etc/letsencrypt/renewal-hooks/post/nginx
sudo certbot renew --dry-run
```

The site serves Flutter and proxies `/api` to loopback. Configure Razorpay's signed webhook to `https://print.example.edu/api/payments/webhook` and verify capture/refunds with test keys first.

`python3 run-server.py run` also provides a foreground backend/worker/frontend on ports 8000/3000. Use systemd/Nginx above for public production hosting; do not run both supervisors simultaneously.

## Department Raspberry Pi

Log in to admin with the seeded credentials. Create the department and station, and copy its generated station ID and unique device token. Tokens are different for every Pi.

On the Pi as its desktop user:

```bash
sudo apt update
sudo apt install -y git cups chromium x11-xserver-utils
git clone https://github.com/RamPrasathM-2005/Autonomous-Printer.git ~/achuppori
cd ~/achuppori
cp print-agent/.env.example print-agent/.env
nano print-agent/.env
```

Set:

```dotenv
AGENT_ID=ID_FROM_ADMIN
AGENT_TOKEN=UNIQUE_TOKEN_FROM_ADMIN
BACKEND_URL=https://print.example.edu/api
KIOSK_WEB_URL=https://print.example.edu
MOCK_CUPS=false
CUPS_SERVER=localhost
PRINTER_NAME=
HOST=127.0.0.1
PORT=5001
STORAGE_ROOT=./storage
LOG_DIR=./logs
```

An empty printer name permits inventory discovery; assigned jobs contain their exact queue. For a dedicated single queue you may set its exact CUPS name. Install:

```bash
sudo bash print-agent/scripts/deploy.sh "$(id -un)"
lpstat -p -d
lpstat -v
curl -f http://127.0.0.1:5001/health
sudo systemctl status print-agent --no-pager
bash print-agent/scripts/verify_agent.sh
```

Configure the HP queue in the Pi's printer settings/CUPS with the driver appropriate for its actual model. USB printers need no server-reachable IP. Print a CUPS test page before testing the application. The installer enables CUPS history, installs pycups and the production HTTP server, validates credentials and installs one per-user kiosk autostart. Log out/in to start it, or run `bash print-agent/deploy/kiosk/kiosk-session.sh` from a graphical terminal. A launch lock prevents duplicate kiosk browser loops. On Wayland configure display idle/blanking in the desktop settings.

Within the next heartbeat (normally 30 seconds), detected queues appear on admin's station discovery view. Map the exact queue to its department/station, use Test Connection and wait for the next heartbeat. Discovery does not automatically assign queues to unrelated departments.

For LAN development use `BACKEND_URL=http://PC_IP:3000/api` and `KIOSK_WEB_URL=http://PC_IP:3000`, with the PC server runner and TCP 3000 allowed. A phone QR URL must be reachable from the phone; `localhost` refers to the phone itself.

## Diagnostics and recovery

On the Pi:

```bash
sudo systemctl show print-agent -p NRestarts -p Result -p MemoryCurrent -p MemoryPeak
sudo journalctl -u print-agent --since '-30 minutes' --no-pager
sudo journalctl -k --since '-30 minutes' | grep -Ei 'oom|killed process|under.voltage' || true
lpstat -W all -o
free -h
df -h
```

On the server:

```bash
sudo journalctl -u achuppori-backend -u achuppori-worker --since '-30 minutes' --no-pager
```

Browser flicker alone does not establish an agent restart: compare service PID, `NRestarts` and logs. `/health` checks the local HTTP process; the admin heartbeat checks authenticated server connectivity. Check CUPS and physical output separately.

Preserve `storage/agent-journal.sqlite3` across ordinary Pi upgrades. It contains pending status events and submitted CUPS IDs so restart resumes monitoring without duplicate submission. A crash between claim and saving a CUPS ID remains ambiguous: inspect CUPS and physical output before retrying. Ambiguous refunds need gateway review before another refund request.

For an intentional Pi reset after resetting the server:

```bash
sudo systemctl stop print-agent
lpstat -W all -o
# Inspect physical output first; this cancels ALL outstanding CUPS jobs.
cancel -a
print-agent/venv/bin/python scripts/reset_data.py --agent-only --yes
nano print-agent/.env
# Copy the newly registered station ID/token before restarting.
sudo systemctl start print-agent
```

Reset clears application spool/journal/logs and preserves printer queues, drivers and CUPS system history. Clear browser site data separately. Do not reset for routine upgrades or while jobs are printing/pending acknowledgement.

## Acceptance checks

Scan QR over Wi-Fi/cellular, upload, inspect options/prices, pay with Razorpay test checkout and enter the code on the Pi. Confirm one physical print and matching customer/admin status. Reject wrong-station and reused codes. Test empty tray, cancelled CUPS job, network loss and agent restart after submission. Verify duplicate signed webhooks and actual gateway refunds. Repeat with your intended MySQL, HP model, SmartiPi display and live credentials before public operation.

Use one API worker while OTP rate limiting is process-local. Color pricing remains INR 10/page. Guest recovery depends on the original browser session. Native builds and physical hardware require device testing.

References: [Waitress options](https://docs.pylonsproject.org/projects/waitress/en/stable/runner.html), [CUPS job history](https://www.cups.org/doc/man-cupsd.conf.html).
