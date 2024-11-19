import pytest
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

def test_status(testing_client):
    """Test the /status endpoint."""
    response = testing_client.get('/status', query_string={"api_key": API_KEY})
    assert response.status_code == 200
    assert response.json['status'] in ["healthy", "unhealthy"]

def test_height(testing_client):
    """Test the /height endpoint."""
    response = testing_client.get('/height') 
    assert response.status_code == 200
    assert 'geth_height' in response.json
