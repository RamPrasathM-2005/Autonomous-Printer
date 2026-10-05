import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.session import get_db
from app.db.models.user import User, UserRole
from app.db.models.department import Department
from app.config.security import hash_password

def test_reports_requires_admin_auth(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    try:
        client = TestClient(app)
        res = client.get('/api/reports/department')
        assert res.status_code in (401, 403)
    finally:
        app.dependency_overrides.clear()

def test_reports_rejects_regular_user(db_session):
    student = User(
        email='student_rep@example.com',
        password_hash=hash_password('Pass123!'),
        role=UserRole.USER,
        is_active=True
    )
    db_session.add(student)
    db_session.commit()

    app.dependency_overrides[get_db] = lambda: db_session
    try:
        client = TestClient(app)
        login_res = client.post('/api/auth/login', json={'email': 'student_rep@example.com', 'password': 'Pass123!'})
        assert login_res.status_code == 200
        token = login_res.json()['access_token']
        res = client.get('/api/reports/department', headers={'Authorization': f'Bearer {token}'})
        assert res.status_code == 403
    finally:
        app.dependency_overrides.clear()

def test_generate_department_report_success(db_session):
    admin = User(
        email='admin@printplatform.local',
        password_hash=hash_password('AdminPass123!'),
        role=UserRole.ADMIN,
        is_active=True
    )
    dept = Department(code="HR_REP", name="Human Resources Rep", description="HR Rep Desc")
    db_session.add(admin)
    db_session.add(dept)
    db_session.commit()

    app.dependency_overrides[get_db] = lambda: db_session
    try:
        client = TestClient(app)
        login_res = client.post('/api/auth/admin/login', json={'email': 'admin@printplatform.local', 'password': 'AdminPass123!'})
        assert login_res.status_code == 200
        token = login_res.json()['access_token']
        headers = {'Authorization': f'Bearer {token}'}

        # 1. Global report across all departments
        res = client.get('/api/reports/department', headers=headers)
        assert res.status_code == 200
        data = res.json()
        assert 'summary' in data
        assert 'user_stats' in data
        assert 'printer_stats' in data
        summary = data['summary']
        assert 'total_jobs' in summary
        assert 'total_pages' in summary
        assert 'successful_jobs' in summary
        assert 'failed_jobs' in summary
        assert 'color_pages' in summary
        assert 'bw_pages' in summary
        assert 'avg_pages_per_job' in summary

        # 2. Specific department report query
        dept_res = client.get(f'/api/reports/department?department_id={dept.id}', headers=headers)
        assert dept_res.status_code == 200
        dept_data = dept_res.json()
        assert dept_data['summary']['department_id'] == dept.id
        assert dept_data['summary']['department_code'] == 'HR_REP'

        # 3. Specific department report via nested endpoint
        nested_res = client.get(f'/api/departments/{dept.id}/report', headers=headers)
        assert nested_res.status_code == 200
        assert nested_res.json()['summary']['department_id'] == dept.id

        # 4. Filter by color
        color_res = client.get('/api/reports/department?is_color=true', headers=headers)
        assert color_res.status_code == 200
    finally:
        app.dependency_overrides.clear()
