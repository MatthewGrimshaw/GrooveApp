"""
Basic health check tests for the API
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch


@pytest.fixture
def mock_db_connection():
    """Mock database connection for testing"""
    with patch("main.get_db_connection") as mock:
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        mock.return_value = mock_conn
        yield mock


@pytest.fixture
def client(mock_db_connection):
    """Create a test client"""
    from main import app

    return TestClient(app)


def test_health_endpoint(client):
    """Test the health check endpoint"""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert "status" in data
    assert data["status"] == "healthy"


def test_root_endpoint(client):
    """Test the root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
