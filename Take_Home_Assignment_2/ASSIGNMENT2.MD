# **ASSIGNMENT2.md**

## Project Overview 
This project implements a Flask API service to fetch synchronization status and block height information for a blockchain-based system, leveraging multiple APIs. The API has endpoints to retrieve the synchronization status and block height from local and remote sources. Additionally, it integrates beacon blockchain slot fetching, with technical details focusing on why a beacon slot is used instead of a block number.

## Technologies Used

- Python 3.x
- Flask for the API framework
- Requests for making HTTP requests to external APIs
- Docker for containerization
- Makefile for task automation
- Pytest for unit testing

## **1. Setup Instructions**

### **1.1 Prerequisites**

Before you start, make sure you have the following installed on your machine:

- **Python 3.10 or higher**: The application uses Python to run.
- **pip**: Python package installer for managing dependencies.
- **Docker** and **Docker-Compose**
- **Make**: A build automation tool (optional, but useful for running commands in an automated way).

### **1.2 Installation Steps**

Follow these steps to set up and run the application:

1. **Clone the repository**:
    ```bash
    unzip <file-name>
    cd <file-name>
    ```

2. **Create and activate a virtual environment (optional)**:
    - On Windows:
      ```bash
      python -m venv venv
      venv\Scripts\activate
      ```
    - On Mac/Linux:
      ```bash
      python3 -m venv venv
      source venv/bin/activate
      ```

3. **Set environment variables**:
    You will need an API key to interact with the beacon chain. Make sure to set the `API_KEY` environment variable.
    - On Linux/Mac:
      ```bash
      export API_KEY="your_api_key_here"
      ```
    - On Windows:
      ```bash
      set API_KEY="your_api_key_here"
      ```

4. **Run the application**:
    ```bash
    make up
    ```
    By default, the app runs on `http://0.0.0.0:8888`.

5. **Testing the Application**:
    You can run the tests using `pytest` to verify the correctness of the endpoints:
    ```bash
    make test
    ```

5. **Testing the Mocked Endpoints**:
    You can run the tests using `pytest` to verify the mocked endpoints:
    ```bash
    make mock
    ```

---

## **2. Deployment Guidelines**

To deploy this application on a server or a cloud platform, you can follow these steps for both **Docker** and **traditional deployment**.

### **2.1 Docker Deployment**

Docker allows you to containerize the application, which makes it portable and easy to deploy anywhere.

#### **2.1.1 Building and Running the Docker Compose**

Alternatively, you can use Docker Compose to handle multi-container setups (e.g., databases, caching, etc.) or simply streamline the container management. Create a `docker-compose.yml` file in your project directory:

```yaml
services:
  # Lighthouse Configuration
  lighthouse:
    image: sigp/lighthouse:latest
    command:
      - lighthouse
      - beacon
      - --network=sepolia
      - --http
      - --http-address=0.0.0.0
      - --execution-endpoint=http://geth:8551
      - --execution-jwt=/jwt/jwtsecret
      - --checkpoint-sync-url=https://sepolia.beaconstate.info
      - --disable-deposit-contract-sync
      - --disable-backfill-rate-limiting
    ports:
      - "5052:5052" # Exposes Lighthouse Beacon Node HTTP interface
      - "9000:9000" # Discovery port
      - "9001:9001" # QUIC port
    volumes:
      - lighthouse_data:/root/.lighthouse
      - jwt_shared:/jwt:rw # Corrected mount point with write permissions
    networks:
      - ethereum
    restart: unless-stopped
    depends_on:
      - geth
    environment:
      - LOG_LEVEL=info

  # Geth Configuration
  geth:
    image: ethereum/client-go:stable
    command: 
      - --sepolia 
      - --syncmode=snap
      - --http #Enable the HTTP-RPC server
      - --http.addr=0.0.0.0 # HTTP-RPC server listening interface
      - --http.api=web3,eth,net,personal # API's offered over the HTTP-RPC interface
      - --authrpc.addr=0.0.0.0 
      - --authrpc.port=8551 
      - --authrpc.vhosts=*
      - --authrpc.jwtsecret=/jwt/jwtsecret
    ports:
      - "8545:8545" # Exposes Geth HTTP RPC interface
      - "8551:8551" # RPC Auth port
    volumes:
      - geth_data:/root/.ethereum
      - jwt_shared:/jwt:rw # Consistent JWT mount with write permissions
    networks:
      - ethereum
    restart: unless-stopped
    environment:
      - GETH_LOG_LEVEL=info

  # Python API Service
  api:
    build: ./api
    ports:
      - "8888:8888"  # Exposes API service
    networks:
      - ethereum
    depends_on:
      - geth
      - lighthouse

volumes:
  geth_data:
  lighthouse_data:
  jwt_shared:

networks:
  ethereum:
    driver: bridge
```

1. Build the Docker Image:

```bash
make build
```

2. Run the Application:

```bash
make up
```

3. Stop and Clean up the Docker Containers:

```bash
make down
```

4. Clean up Docker Containers and Volumes:

```bash
make clean
```

## Considerations & Assumptions
- Error Handling: The application gracefully handles errors, logging them for further analysis. Any exception in the fetching or synchronization logic is caught, and a 500 error response is returned to the client.
- API Key Validation: The /status endpoint requires an API key to fetch the latest beacon slot from a public testnet. The API key is provided as a query parameter (api_key).
- Testing: Unit tests are implemented to ensure the API behaves as expected. These tests mock external API calls to simulate various scenarios.
- CORS: Cross-Origin Resource Sharing (CORS) is not implemented, assuming that the API will be used in a controlled environment (e.g., internal services or with proper API token management).

## Additional Considerations During Implementation
- API Rate Limiting: Since external APIs (such as Beaconcha for beacon slots) may have rate limits, the system should be designed to handle rate-limited responses gracefully, possibly implementing retries or backoff mechanisms.
- Scalability: The Flask application is suitable for small to medium-scale use cases. For large-scale deployments, consider using a WSGI server (e.g., Gunicorn) in combination with Nginx for handling more concurrent connections efficiently.
- Security: Ensure the API key used for accessing beacon slot data is kept secure, and consider implementing more robust authentication mechanisms in a production environment.

## Docker Commands Explanation

Lighthouse and Beacon Flags
--network=sepolia: Specifies that the Ethereum 2.0 beacon chain should operate on the Sepolia test network.
--http: Enables the HTTP API interface.
--http-address=0.0.0.0: Exposes the HTTP API on all network interfaces, allowing external access.
--execution-endpoint=http://geth:8551: Specifies the endpoint for the execution layer, typically the Geth node.
--execution-jwt=/jwt/jwtsecret: Provides the path to the JSON Web Token used for authentication between the beacon node and the execution layer.
--checkpoint-sync-url=https://sepolia.beaconstate.info: Specifies the URL to use for syncing the beacon node state from a checkpoint URL.


## Mock Tests Implementation

Due to long-running sync from sepolia testnet etherium blokchain, i've decided to implement mocking of boh endpoints with expected results

- `test_status_success`:
Simulates a healthy state with valid mocked values. This test ensures the /status endpoint behaves as expected under normal conditions.

- `test_status_failure`:
Simulates an unhealthy state but deliberately asserts for a 200 status and "healthy" status, which will fail because the actual mocked response will indicate an unhealthy state.

- `test_height_success`:
Simulates a successful /height response with valid mocked values. This test will pass.

- `test_height_failure`:
Simulates a failure due to an exception being raised in the get_local_block_height function. 

However, it deliberately asserts for a 200 status and a valid geth_heigth, which will fail because the actual response will indicate an error.

