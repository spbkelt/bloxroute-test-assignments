import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

def fetch_block_height(url, payload):
    """Fetch block height from a specified URL."""
    try:
        response = requests.post(url, json=payload, timeout=5)
        response.raise_for_status()
        block_hex = response.json().get("result")
        if not block_hex:
            raise ValueError("Invalid response: 'result' field missing")
        return int(block_hex, 16)  # Convert hex block number to int
    except Exception as e:
        app.logger.error(f"Error fetching block height from {url}: {e}")
        raise

def fetch_latest_beacon_slot(base_url, query_params):
    try:
        response = requests.get(base_url, params=query_params, timeout=5)
        response.raise_for_status()
        
        # Check if response has valid data
        data = response.json().get("data", {})
        slot = data.get("slot")
        if not slot:
            raise ValueError("Invalid response: 'slot' field missing")

        return int(slot)
    
    except requests.exceptions.RequestException as e:
        app.logger.error(f"Request error: {e}")
        raise  # re-raise the error for logging and debugging
    except ValueError as e:
        app.logger.error(f"Value error: {e}")
        raise
    except Exception as e:
        app.logger.error(f"Unexpected error: {e}")
        raise


def fetch_local_beacon_slot(url):
    """Fetch the beacon slot from a specified URL."""
    try:
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        slot = response.json().get("data", {}).get("header").get("message").get("slot")
        if not slot:
            raise ValueError("Invalid response: 'slot' field missing")
        return int(slot)
    except Exception as e:
        app.logger.error(f"Error fetching beacon slot from {url}: {e}")
        raise

def get_local_block_height():
    """Fetch block height from the local Geth node."""
    return fetch_block_height(
        "http://localhost:8545",
        {"jsonrpc": "2.0", "method": "eth_blockNumber", "params": [], "id": 1}
    )

def get_latest_block_height():
    """Fetch the latest block height from a public Geth testnet source."""
    return fetch_block_height(
        "https://rpc.sepolia.org",
        {"jsonrpc": "2.0", "method": "eth_blockNumber", "params": [], "id": 1}
    )

def get_local_beacon_slot():
    """Fetch slot number from the local Lighthouse node."""
    return fetch_local_beacon_slot("http://localhost:5052/eth/v1/beacon/headers/finalized")

def get_latest_beacon_slot(api_key):
    """Fetch slot number from a public Lighthouse testnet source."""
    base_url = "https://beaconcha.in/api/v1/slot/latest"
    query_params = {"apiKey": api_key}  # Define query parameters as a dictionary
    return fetch_latest_beacon_slot(base_url, query_params)

def check_sync_status(local_block, latest_block, local_slot, latest_slot, threshold=20):
    """
    Check synchronization status based on differences in block height and beacon slots.
    
    Args:
        local_block (int): Local block height.
        real_block (int): Real-time block height.
        local_slot (int): Local beacon slot.
        real_slot (int): Real-time beacon slot.
        threshold (int): Acceptable difference threshold.
    
    Returns:
        dict: Status
    """
    block_diff = abs(latest_block - local_block)
    slot_diff = abs(latest_slot - local_slot)

    status = "healthy" if block_diff <= threshold and slot_diff <= threshold else "unhealthy"
    return {
        "status": status
    }

@app.route('/status', methods=['GET'])
def status():
    """API endpoint to check synchronization status."""
    try:
        # Retrieve API key from query parameters
        api_key = request.args.get("api_key")
        if not api_key:
            return jsonify({"error": "Missing API key"}), 400
        
        # Fetch local and real-time values
        local_block_height = get_local_block_height()
        latest_block_height = get_latest_block_height()
        local_beacon_slot = get_local_beacon_slot()
        latest_beacon_slot = get_latest_beacon_slot(api_key)

        # Evaluate synchronization status
        sync_status = check_sync_status(
            local_block_height, latest_block_height,
            local_beacon_slot, latest_beacon_slot
        )

        # Return response based on status
        status_code = 200 if sync_status["status"] == "healthy" else 500
        return jsonify(sync_status), status_code
    except Exception as e:
        app.logger.error(f"Error in /status: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/height', methods=['GET'])
def heigth():
    """API endpoint to fetch the local Geth block height."""
    try:
        local_block_height = get_local_block_height()
        return jsonify({"geth_heigth": local_block_height}), 200
    except Exception as e:
        app.logger.error(f"Error in /height: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8888)
