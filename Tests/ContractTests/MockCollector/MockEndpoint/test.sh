#!/bin/bash

# Simple test script to verify the contract test endpoint

echo "Testing Contract Test Endpoint..."
echo ""

# Test 200 OK
echo "Testing /200 endpoint (200 OK):"
curl -s http://localhost:8080/200
echo -e "\n"

# Test 404 ResourceNotFound
echo "Testing /404 endpoint (404 ResourceNotFound):"
curl -s http://localhost:8080/404
echo -e "\n"

# Test 500 InternalServerException
echo "Testing /500 endpoint (500 InternalServerException):"
curl -s http://localhost:8080/500
echo -e "\n"

echo "Tests completed."
