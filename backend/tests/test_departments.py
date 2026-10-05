import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.session import get_db
from app.db.models.user import User, UserRole
from app.db.models.department import Department
from app.db.models.printer import Printer
from app.config.security import hash_password

def test_departments_requires_admin_auth(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    try:
        client = TestClient(app)
        res = client.get('/api/departments')
        assert res.status_code in (401, 403)
    finally:
        app.dependency_overrides.clear()

def test_departments_rejects_regular_user(db_session):
    student = User(
        email='student_dept@example.com',
        password_hash=hash_password('Pass123!'),
        role=UserRole.USER,
        is_active=True
    )
    db_session.add(student)
    db_session.commit()

    app.dependency_overrides[get_db] = lambda: db_session
    try:
        client = TestClient(app)
        login_res = client.post('/api/auth/login', json={'email': 'student_dept@example.com', 'password': 'Pass123!'})
        assert login_res.status_code == 200
        token = login_res.json()['access_token']
        res = client.get('/api/departments', headers={'Authorization': f'Bearer {token}'})
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()

def test_departments_list_and_search(db_session):
    admin = User(
        email='admin@printplatform.local',
        password_hash=hash_password('AdminPass123!'),
        role=UserRole.ADMIN,
        is_active=True
    )
    dept_hr = Department(code="HR_TEST", name="Human Resources Test", description="HR Test Desc")
    dept_it = Department(code="IT_TEST", name="Information Tech Test", description="IT Test Desc")
    db_session.add(admin)
    db_session.add(dept_hr)
    db_session.add(dept_it)
    db_session.commit()

    app.dependency_overrides[get_db] = lambda: db_session
    try:
        client = TestClient(app)
        login_res = client.post('/api/auth/admin/login', json={'email': 'admin@printplatform.local', 'password': 'AdminPass123!'})
        assert login_res.status_code == 200
        token = login_res.json()['access_token']
        headers = {'Authorization': f'Bearer {token}'}

        # 1. List all departments
        res = client.get('/api/departments', headers=headers)
        assert res.status_code == 200
        items = res.json()
        assert isinstance(items, list)
        assert len(items) >= 2
        first = items[0]
        assert 'id' in first
        assert 'code' in first
        assert 'name' in first
        assert 'users_count' in first
        assert 'printers_count' in first
        assert 'jobs_count' in first
        assert 'pages_count' in first

        # 2. Search query filter
        search_res = client.get('/api/departments?q=Human', headers=headers)
        assert search_res.status_code == 200
        search_items = search_res.json()
        assert any(d['code'] == 'HR_TEST' for d in search_items)
        assert not any(d['code'] == 'IT_TEST' for d in search_items)

        # 3. Department details
        detail_res = client.get(f'/api/departments/{dept_hr.id}', headers=headers)
        assert detail_res.status_code == 200
        detail = detail_res.json()
        assert detail['id'] == dept_hr.id
        assert detail['code'] == 'HR_TEST'
        assert 'users' in detail
        assert 'printers' in detail
        assert 'recent_jobs' in detail

        # 4. Non-existent department 404
        not_found = client.get('/api/departments/999999', headers=headers)
        assert not_found.status_code == 404
    finally:
        app.dependency_overrides.clear()
