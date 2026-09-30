"""Explicit local station provisioning. No default admin password or device secret."""
import os
from pathlib import Path
from dotenv import dotenv_values
from app.config.database import SessionLocal
from app.config.security import hash_token
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer

def seed():
    agent = dotenv_values(Path(__file__).resolve().parents[3] / 'print-agent' / '.env')
    token = os.getenv('AGENT_TOKEN') or agent.get('AGENT_TOKEN', '')
    if len(token) < 32: raise RuntimeError('Provide a random 32+ character AGENT_TOKEN.')
    with SessionLocal() as db:
        if not db.get(PrintServer, 'PRINT-SERVER-001'):
            db.add(PrintServer(id='PRINT-SERVER-001', name='Central Library Station',
                location='Main Campus Library Floor 1', device_token_hash=hash_token(token), status=PrintServerStatus.OFFLINE))
            db.flush()
            db.add(Printer(id='printer_central_01', server_id='PRINT-SERVER-001',
                cups_printer_name=agent.get('PRINTER_NAME', 'Default_Office_Printer'),
                display_name='Station printer', supports_color=True, supports_duplex=True, is_active=True))
            db.commit()
    print('Station provisioned. Existing station credentials were not changed.')

if __name__ == '__main__': seed()
