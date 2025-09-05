# Mock Endpoint

A simple HTTP server that returns different status codes based on the requested path. This service is designed to be used in contract tests to verify how clients handle various HTTP responses.

## Available Endpoints

- `/` or `/200` - Returns 200 OK
- `/404` - Returns 404 ResourceNotFound
- `/500` - Returns 500 InternalServerException

## Running Locally

```bash
node server.js
```

## Docker

Build the image:
```bash
docker build -t MockEndpoint .
```

Run the container:
```bash
docker run -p 8080:8080 MockEndpoint
```

## Docker Compose

This service is included in the Docker Compose file at `ContractTests/compose.yaml` for use in contract testing.
