import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.db.models.user import User, UserRole

import uuid

client = TestClient(app)

def test_email_otp_flow_and_student_auth():
    uid = uuid.uuid4().hex[:8]
    test_email = f"student_otp_{uid}@example.com"
    test_roll = f"ROLL_{uid.upper()}"

    # 1. Login with unregistered email should return 404
    resp = client.post("/api/auth/send-otp", json={"email": test_email, "purpose": "login"})
    assert resp.status_code == 404
    assert resp.json()["error"] == "USER_NOT_FOUND"

    # 2. Signup OTP request for new email should succeed
    resp = client.post("/api/auth/send-otp", json={"email": test_email, "purpose": "signup"})
    assert resp.status_code == 200
    data = resp.json()
    assert "email" in data
    assert data["email"] == test_email

    # Retrieve actual generated 6-digit OTP from auth_service memory store
    from app.services.auth_service import auth_service
    assert test_email in auth_service._email_otps
    otp = auth_service._email_otps[test_email]["otp"]
    assert len(otp) == 6

    # 3. Verify OTP
    resp = client.post("/api/auth/verify-otp", json={"email": test_email, "otp": otp})
    assert resp.status_code == 200
    assert resp.json()["valid"] is True

    # 4. Student signup
    signup_payload = {
        "full_name": "Test Student",
        "roll_number": test_roll,
        "email": test_email,
        "department": "Computer Science (CSE)",
        "otp": otp
    }
    resp = client.post("/api/auth/student/signup", json=signup_payload)
    assert resp.status_code == 201
    auth_data = resp.json()
    assert "access_token" in auth_data
    assert auth_data["user"]["email"] == test_email
    assert auth_data["user"]["roll_number"] == test_roll

    token = auth_data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 5. Fetch /me profile
    resp = client.get("/api/auth/me", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == test_email

    # 6. Student login with email: request login OTP
    resp = client.post("/api/auth/send-otp", json={"email": test_email, "purpose": "login"})
    assert resp.status_code == 200
    login_otp = auth_service._email_otps[test_email]["otp"]
    assert len(login_otp) == 6

    login_payload = {
        "email": test_email,
        "otp": login_otp
    }
    resp = client.post("/api/auth/student/login", json=login_payload)
    assert resp.status_code == 200
    assert "access_token" in resp.json()
    assert resp.json()["user"]["email"] == test_email
