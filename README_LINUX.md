# Ubuntu setup

Use the shared [setup guide](README.md#setup-on-windows-and-ubuntu).

```bash
python3 scripts/project.py setup
bash start_all.sh
```

Open http://127.0.0.1:3000/. The launcher uses `.venv`, starts the API, payment reconciliation worker, print agent and frontend, and checks readiness. Ctrl+C stops its processes. Logs are in `.runtime/`.

After pulling, repeat setup if dependencies changed and restart. Changed frontend files rebuild automatically. Use `bash start_all.sh --build` to force a rebuild, or `--hot` for development.

Fresh installations use SQLite and simulated printing. Configure Razorpay test keys in `backend/.env` for checkout. For physical printing, configure CUPS and install `pycups`, set `MOCK_CUPS=false` and your printer name in `print-agent/.env`, and provision the station with a matching device token. See the [agent guide](print-agent/README.md).

The default local keypad is http://127.0.0.1:5001/kiosk; agent `PORT` overrides this. Run `bash start_tunnel.sh` separately for a public tunnel. Legacy desktop terminal scripts are separate utilities; use the standard launcher for the shared setup.
