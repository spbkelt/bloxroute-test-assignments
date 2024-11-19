# Makefile for building, testing, and running the Flask API service

# Build and run the Docker containers in detached mode
up:
	docker-compose up -d

# Stop and remove the Docker containers
down:
	docker-compose down

# Clean up Docker containers and volumes
clean:
	docker-compose down -v

# Lint Python code
lint:
	pylint api/app.py

# Run Unit Tests
test:
	pytest --maxfail=1 --disable-warnings -q api/test_api.py

# Run Unit Tests
mock:
	pytest --maxfail=1 --disable-warnings -q api/test_api_mock.py
