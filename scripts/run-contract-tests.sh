#!/bin/bash

# Contract Tests Runner
# Migrated from .github/actions/contract_tests/action.yml

set -e

# Default values
DESTINATION=""
MOCK_ENDPOINT_PORT=8181

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --destination)
      DESTINATION="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --destination <platform>"
      echo "  --destination  Platform (e.g., ios, tvos, watchos, visionos)"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$DESTINATION" ]]; then
  echo "Error: --destination is required"
  echo "Use --help for usage information"
  exit 1
fi

echo "Running contract tests for $DESTINATION"

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cleanup function
cleanup() {
  echo "Cleaning up processes..."
  # Kill any processes using port 3000 (AwsOtelUI)
  lsof -ti:3000 | xargs kill -9 2>/dev/null || true
  # Clean up output directory
  cd "$PROJECT_ROOT/Examples/AwsOtelUI"
  npm run clean
}

# Cleanup on script exit
# trap cleanup EXIT

# Initial cleanup to ensure clean state
echo "Ensuring clean environment..."
cleanup

# Prepare directory
echo "Preparing directory..."
mkdir -p "$PROJECT_ROOT/Examples/AwsOtelUI/out"



# Start AwsOtelUI server
echo "Starting AwsOtelUI server..."
cd "$PROJECT_ROOT/Examples/AwsOtelUI"
npm i &
npm start &
SERVER_PID=$!
sleep 5

# Generate spans and logs
echo "Generating spans and logs for $DESTINATION..."
cd "$PROJECT_ROOT/Examples/SimpleAwsDemo"

# Build and run the app with contract test mode
case $DESTINATION in
  ios)
    make contract-test-generate-data-$DESTINATION
    ;;
esac

# Wait for telemetry generation
sleep 15

# List generated files
echo "Generated files:"
ls -al "$PROJECT_ROOT/Examples/AwsOtelUI/out"

# Verify contracts
cd "$PROJECT_ROOT"
swift test --filter ContractTests

echo "Contract tests completed successfully!"