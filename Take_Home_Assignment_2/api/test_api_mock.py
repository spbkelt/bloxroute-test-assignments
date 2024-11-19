import pytest
from unittest.mock import patch
from app import app  # Ensure you import the app instance from your app module
import os

# API Key is taken from https://sepolia.beaconcha.in/user/settings#api
API_KEY = os.getenv("API_KEY", "QTlqZXNhZEtkUUVza3hnSmxvZVM5OEV4MmJSRw")

@pytest.fixture(name="testing_client")
def client():
    """Fixture to provide a test client for the app."""
    with app.test_client() as testing_client:
        with app.app_context():
            yield testing_client

# Mock values for success
MOCK_LOCAL_BLOCK_HEIGHT = 7105325
MOCK_LATEST_BLOCK_HEIGHT = 7105326  # Minimal difference to ensure healthy
MOCK_LOCAL_BEACON_SLOT = 123456
MOCK_LATEST_BEACON_SLOT = 123457  # Minimal difference to ensure healthy

# Mock values for failure
MOCK_LARGE_DIFFERENCE_BLOCK_HEIGHT = MOCK_LOCAL_BLOCK_HEIGHT + 50  # Large difference to simulate failure
MOCK_LARGE_DIFFERENCE_BEACON_SLOT = MOCK_LOCAL_BEACON_SLOT + 50  # Large difference to simulate failure

### Test Success Scenarios

@patch("app.get_local_block_height", return_value=MOCK_LOCAL_BLOCK_HEIGHT)
@patch("app.get_latest_block_height", return_value=MOCK_LATEST_BLOCK_HEIGHT)
@patch("app.get_local_beacon_slot", return_value=MOCK_LOCAL_BEACON_SLOT)
@patch("app.get_latest_beacon_slot", return_value=MOCK_LATEST_BEACON_SLOT)
def test_status_success(mock_local_block, mock_latest_block, mock_local_slot, mock_latest_slot, testing_client):
    """Test the /status endpoint for a successful response."""
    response = testing_client.get('/status', query_string={"api_key": API_KEY})
    assert response.status_code == 200
    assert response.json['status'] == "healthy"  # Healthy response expected


@patch("app.get_local_block_height", return_value=MOCK_LOCAL_BLOCK_HEIGHT)
def test_height_success(mock_local_block, testing_client):
    """Test the /height endpoint for a successful response."""
    response = testing_client.get('/height')
    assert response.status_code == 200
    assert response.json['geth_heigth'] == MOCK_LOCAL_BLOCK_HEIGHT  # This should pass

### Test Failure Scenarios

@patch("app.get_local_block_height", return_value=MOCK_LOCAL_BLOCK_HEIGHT)
@patch("app.get_latest_block_height", return_value=MOCK_LARGE_DIFFERENCE_BLOCK_HEIGHT)
@patch("app.get_local_beacon_slot", return_value=MOCK_LOCAL_BEACON_SLOT)
@patch("app.get_latest_beacon_slot", return_value=MOCK_LARGE_DIFFERENCE_BEACON_SLOT)
def test_status_failure(mock_local_block, mock_latest_block, mock_local_slot, mock_latest_slot, testing_client):
    """Test the /status endpoint for an unhealthy response."""
    response = testing_client.get('/status', query_string={"api_key": API_KEY})
    assert response.status_code == 200  # Intentional mismatch: This should fail
    assert response.json['status'] == "healthy"  # Intentional mismatch: This should fail

@patch("app.get_local_block_height", side_effect=Exception("Simulated error"))
def test_height_failure(mock_local_block, testing_client):
    """Test the /height endpoint for a failure response."""
    response = testing_client.get('/height')
    assert response.status_code == 200  # Intentional mismatch: This should fail
    assert "geth_heigth" in response.json  # Intentional mismatch: This should fail
