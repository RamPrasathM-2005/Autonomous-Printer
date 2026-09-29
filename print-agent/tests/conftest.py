import pytest
from app.main import create_app

@pytest.fixture
def agent_app():
    app = create_app()
    app.config["TESTING"] = True
    return app

@pytest.fixture
def agent_client(agent_app):
    return agent_app.test_client()
