from unittest.mock import Mock


def test_remote_network_cannot_operate_keypad(agent_client, monkeypatch):
    release = Mock()
    monkeypatch.setattr('app.routes.local.backend_client.release_job', release)
    response = agent_client.post('/local/release', json={'otp': '123456'}, environ_overrides={'REMOTE_ADDR': '192.168.1.50'})
    assert response.status_code == 403
    release.assert_not_called()


def test_cross_origin_browser_cannot_operate_keypad(agent_client):
    response = agent_client.post('/local/release', json={'otp': '123456'}, headers={'Origin': 'https://attacker.example'})
    assert response.status_code == 403
    assert agent_client.post('/local/release', data='otp=123456').status_code == 415


def test_testing_mode_does_not_disable_throttling(agent_client):
    for _ in range(10):
        assert agent_client.post('/local/release', json={'otp': 'bad'}).status_code == 400
    assert agent_client.post('/local/release', json={'otp': 'bad'}).status_code == 429


def test_json_arrays_are_rejected_without_server_error(agent_client):
    assert agent_client.post('/local/release', json=[1, 2]).status_code == 400


def test_kiosk_has_browser_security_headers(agent_client):
    response = agent_client.get('/kiosk')
    assert response.headers['X-Frame-Options'] == 'DENY'
    assert response.headers['X-Content-Type-Options'] == 'nosniff'


def test_dns_rebinding_host_cannot_operate_keypad(agent_client):
    response = agent_client.post('/local/release', json={'otp': '123456'},
        headers={'Host': 'attacker.example', 'Origin': 'http://attacker.example'})
    assert response.status_code == 403
