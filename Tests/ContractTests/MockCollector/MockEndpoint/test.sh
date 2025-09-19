#!/bin/bash

# Simple test script to verify the contract test endpoint

echo "Testing Contract Test Endpoint..."
echo ""

# Test 200 OK
echo "Testing /200 endpoint (200 OK):"
HTTP_STATUS_200=$(curl -s -o /dev/null http://localhost:8181/200 -w "%{http_code}")
echo -e "$HTTP_STATUS_200 \n"
if [[ "$HTTP_STATUS_200" -ne "200" ]]
    echo "Response code should have been 200"
    exit 1
fi

# Test 404 ResourceNotFound
echo "Testing /404 endpoint (404 ResourceNotFound):"
HTTP_STATUS_404=$(curl -s -o /dev/null http://localhost:8181/404 -w "%{http_code}")
echo -e "$HTTP_STATUS_404 \n"
if [[ "$HTTP_STATUS_404" -ne "404" ]]
    echo "Response code should have been 404"
    exit 1
fi

# Test 500 InternalServerException
echo "Testing /500 endpoint (500 InternalServerException):"
HTTP_STATUS_500=$(curl -s -o /dev/null http://localhost:8181/500 -w "%{http_code}")
echo -e "$HTTP_STATUS_500 \n"
if [[ "$HTTP_STATUS_500" -ne "500" ]]
    echo "Response code should have been 500"
    exit 1
fi

echo "Tests completed."
