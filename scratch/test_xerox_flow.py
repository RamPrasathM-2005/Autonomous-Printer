import io
import time
import uuid
from decimal import Decimal
import requests
from pathlib import Path

import os
BASE_URL = os.environ.get("BACKEND_URL", "http://172.17.3.5:8000/api")

def create_sample_pdf() -> bytes:
    """Generate a valid minimal 1-page PDF for test printing."""
    pdf_content = (
        b"%PDF-1.4\n"
        b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
        b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
        b"3 0 obj<</Type/Page/MediaBox[0 0 595 842]/Parent 2 0 R/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n"
        b"4 0 obj<</Length 55>>stream\n"
        b"BT /F1 24 Tf 100 700 Td (SmartPrint Xerox Test Print) Tj ET\n"
        b"endstream\nendobj\n"
        b"5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n"
        b"xref\n0 6\n0000000000 65535 f\n0000000010 00000 n\n0000000053 00000 n\n0000000102 00000 n\n0000000212 00000 n\n0000000318 00000 n\n"
        b"trailer<</Size 6/Root 1 0 R>>\nstartxref\n386\n%%EOF\n"
    )
    return pdf_content

def test_flow():
    import sys
    sys.path.insert(0, "/home/smartprint/Documents/SmartPrint/backend")
    from app.db.base import Base
    from app.config.database import SessionLocal
    from app.db.models.order import Order
    from app.db.models.payment import Payment
    from app.db.models.otp import OTP
    from app.db.models.print_job import PrintJob
    from app.services.payment_service import PaymentService
    from app.utils.crypto import decrypt_value

    print("=== Step 1: Uploading Document via Cloudflare Tunnel ===")
    pdf_bytes = create_sample_pdf()
    files = {"file": ("test_xerox_doc.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
    res = requests.post(f"{BASE_URL}/documents/upload", files=files, timeout=15)
    print("Upload status:", res.status_code)
    assert res.status_code == 201, f"Document upload failed: {res.text}"
    doc_data = res.json()
    doc_id = doc_data["documentId"]
    print(f"Document uploaded: ID={doc_id}, pages={doc_data.get('pages')}")

    print("\n=== Step 2: Creating Print Order for Station PRINT-SERVER-001 ===")
    order_payload = {
        "documentId": doc_id,
        "printServerId": "PRINT-SERVER-001",
        "rollNumber": "TEST_ROLL_01",
        "department": "Engineering",
        "settings": {
            "copies": 1,
            "colour": False,
            "colorMode": "BW",
            "duplex": False,
            "paperSize": "A4",
            "selected_printer": "HP_LaserJet_400_M401dn_F36EC0",
            "pageRange": "all"
        }
    }
    res = requests.post(f"{BASE_URL}/orders", json=order_payload, timeout=15)
    print("Order create status:", res.status_code)
    assert res.status_code == 201, f"Order creation failed: {res.text}"
    order_data = res.json()
    order_id = order_data["id"]
    print(f"Order created: ID={order_id}, Amount={order_data.get('amount')}")

    print("\n=== Step 3: Fulfilling Payment & Generating 6-Digit Release OTP ===")
    # Create payment entry
    pay_res = requests.post(f"{BASE_URL}/payments/create", json={"orderId": order_id}, timeout=15)
    print("Payment create status:", pay_res.status_code)
    assert pay_res.status_code == 201, f"Payment creation failed: {pay_res.text}"

    with SessionLocal() as db:
        order = db.query(Order).filter(Order.id == order_id).first()
        payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        test_payment_entity = {
            "id": f"pay_{uuid.uuid4().hex[:14]}",
            "order_id": payment.razorpay_order_id,
            "status": "captured",
            "amount": int(Decimal(str(order.amount)) * 100),
            "currency": order.currency,
            "amount_refunded": 0
        }
        PaymentService._fulfill(db, order, payment, test_payment_entity, "test_signature")

    # Fetch decrypted release OTP
    otp_code = None
    with SessionLocal() as db:
        otp_rec = db.query(OTP).filter(OTP.order_id == order_id, OTP.active == True).first()
        if otp_rec and otp_rec.encrypted_value:
            otp_code = decrypt_value(otp_rec.encrypted_value)

    print(f"Generated Release OTP: {otp_code}")
    assert otp_code, "Failed to retrieve OTP"

    print("\n=== Step 4: Releasing Job via Kiosk with OTP (Simulating Customer at Station) ===")
    release_res = requests.post(f"{BASE_URL}/agent/release-kiosk", json={"otp": otp_code}, timeout=15)
    print("Kiosk Release response:", release_res.status_code, release_res.text)
    assert release_res.status_code == 200, "Kiosk release failed"
    rel_data = release_res.json()
    job_id = rel_data.get("jobId")
    print(f"Job Released: ID={job_id}")

    print("\n=== Step 5: Monitoring Raspberry Pi Print Agent Processing Job ===")
    for i in range(25):
        time.sleep(2)
        with SessionLocal() as db:
            job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
            if job:
                print(f"[{i*2}s] Print Job Status: {job.status.value}")
                if job.status.value == "COMPLETED":
                    print(f"\n[SUCCESS] Print Job completed successfully on Raspberry Pi! (Job ID: {job_id})")
                    return True
                elif job.status.value == "FAILED":
                    print(f"\n[FAIL] Print Job failed: {job.error_code} - {job.error_message}")
                    return False

    print("\n[TIMEOUT] Job did not reach COMPLETED in 50 seconds.")
    return False

if __name__ == "__main__":
    test_flow()
