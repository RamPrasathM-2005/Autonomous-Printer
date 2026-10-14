# Raspberry Pi kiosk startup

The agent is the system service `print-agent.service`. The graphical desktop must
log in automatically as the installation user; its `kiosk.desktop` autostart runs
`print-agent/deploy/kiosk/kiosk-session.sh`.

The agent starts after the local network stack and CUPS without waiting for
internet connectivity. The kiosk waits for `/kiosk` to respond before navigating.
Chromium uses `--password-store=basic` for this dedicated, credential-free kiosk
to prevent a locked desktop keyring dialog from blocking unattended login.
Chromium uses software rendering to avoid the observed blank touchscreen and a
profile in the user's runtime directory, discarded at reboot. No customer login
or printer credentials are stored in this kiosk profile. The launcher reopens
Chromium if it exits and uses a lock to prevent duplicate launchers.

Check on the Pi:

```bash
systemctl status print-agent --no-pager
journalctl -b -u print-agent --no-pager
curl -fsS http://127.0.0.1:5001/health
```

The screen requires the graphical OS session to finish starting; it cannot appear
immediately at power-on. The QR can render without internet, but its destination
must remain reachable for uploads. Temporary Cloudflare URLs need updating in
`KIOSK_WEB_URL` when the tunnel URL changes.
