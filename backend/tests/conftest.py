import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.config.database import Base
from app.db.session import get_db
from app.db.models.user import User, UserRole
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.config.security import hash_password, hash_token

# In-memory SQLite for fast, isolated testing
TEST_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db_session():
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def client(db_session):
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()

@pytest.fixture
def test_user(db_session):
    user = User(
        email="student@university.edu",
        phone="9876543210",
        full_name="Test Student",
        password_hash=hash_password("SecurePass123!"),
        role=UserRole.USER,
        is_active=True
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def test_agent_token():
    return "test-agent-device-token-secret"

@pytest.fixture
def test_print_server(db_session, test_agent_token):
    server = PrintServer(
        id="PRINT-SERVER-001",
        name="Main Library Print Station",
        location="Library Floor 1",
        device_token_hash=hash_token(test_agent_token),
        status=PrintServerStatus.ONLINE
    )
    db_session.add(server)
    db_session.commit()
    db_session.refresh(server)
    return server

import io
from pypdf import PdfWriter

def create_sample_pdf(page_count: int = 3) -> bytes:
    writer = PdfWriter()
    for _ in range(page_count):
        writer.add_blank_page(width=72, height=72)
    buf = io.BytesIO()
    writer.write(buf)
    return buf.getvalue()

def get_auth_token(client, test_user):
    login_res = client.post("/api/auth/login", json={
        "email": test_user.email,
        "password": "SecurePass123!"
    })
    return login_res.json()["access_token"]
