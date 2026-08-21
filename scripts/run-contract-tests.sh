#!/bin/bash

# Contract Tests Runner
# Migrated from .github/actions/contract_tests/action.yml

set -e

# Default values
DESTINATION=""
MOCK_ENDPOINT_PORT=8181

# The local AwsOtelUI server. Exporting here is what makes the default run hermetic; the app
# itself has no localhost fallback (with nothing set it targets the real regional endpoint).
HERMETIC_ENDPOINT="http://localhost:3000"

# Harness configuration. Flags win over the environment; anything still empty is defaulted by
# the app (region/app monitor id) or below (endpoint).
ENDPOINT="${AWS_OTEL_CONTRACT_EXPORT_ENDPOINT:-}"
REGION="${AWS_OTEL_CONTRACT_REGION:-}"
APP_MONITOR_ID="${AWS_OTEL_CONTRACT_APP_MONITOR_ID:-}"
RUN_ID="${AWS_OTEL_CONTRACT_RUN_ID:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --destination)
      DESTINATION="$2"
      shift 2
      ;;
    --endpoint)
      ENDPOINT="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --app-monitor-id)
      APP_MONITOR_ID="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --destination <platform> [--endpoint <url>] [--region <region>] [--app-monitor-id <id>] [--run-id <key>]"
      echo "  --destination     Platform (e.g., ios, tvos, watchos, visionos)"
      echo "  --endpoint        Export endpoint. Defaults to $HERMETIC_ENDPOINT (hermetic mode:"
      echo "                    starts the local AwsOtelUI server and verifies the dumped output)."
      echo "                    Any other endpoint selects real-endpoint mode: no local :3000"
      echo "                    server and no output assertions (nothing is written locally)."
      echo "  --region          AWS region for AwsConfig. Defaults to the app's built-in default."
      echo "  --app-monitor-id  RUM app monitor id (a UUID) for AwsConfig. Secret in CI."
      echo "  --run-id          Run-scoped correlation key. Becomes the"
      echo "                    aws.otel.contract.run.id resource attribute on every exported"
      echo "                    signal, so scripts/verify-put-to-get.sh can find this run's"
      echo "                    events. Optional; omitted in hermetic mode."
      echo ""
      echo "Each flag also reads a matching environment variable:"
      echo "  AWS_OTEL_CONTRACT_EXPORT_ENDPOINT, AWS_OTEL_CONTRACT_REGION,"
      echo "  AWS_OTEL_CONTRACT_APP_MONITOR_ID, AWS_OTEL_CONTRACT_RUN_ID"
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

# Hermetic mode is the default: no endpoint supplied, or the local AwsOtelUI server supplied
# explicitly (with or without a trailing slash).
if [[ -z "$ENDPOINT" ]]; then
  ENDPOINT="$HERMETIC_ENDPOINT"
fi
if [[ "${ENDPOINT%/}" == "$HERMETIC_ENDPOINT" ]]; then
  HERMETIC=true
else
  HERMETIC=false
fi

# Reject an endpoint the app would refuse, here rather than 10 minutes into an xcodebuild run.
# In real-endpoint mode there are no output assertions, so an unusable endpoint would otherwise
# produce a green run that exported nothing. Mirrors ContractTestConfig.resolveEndpoints — http(s),
# a host, and no query, fragment or embedded credentials — but is deliberately a shade stricter: the
# scheme must be lowercase, so the literal hermetic comparison above cannot be side-stepped by
# spelling the local server as HTTP://localhost:3000 (which the app would accept while this script
# had already decided not to start it).
if [[ ! "$ENDPOINT" =~ ^https?://[^/?#@[:space:]]+(/[^?#[:space:]]*)?$ ]]; then
  echo "Error: endpoint must be an http(s) URL with a host and no query, fragment or credentials"
  echo "       (the value is not echoed: it is a secret in CI). Use --help for examples."
  exit 1
fi

# Reject a correlation key that the fetch step could not search for verbatim. Keep this in step
# with the same check in scripts/verify-put-to-get.sh: if the two disagree, the put side stamps a
# key the get side never looks for and the job fails as a timeout with no explanation.
if [[ -n "$RUN_ID" && ! "$RUN_ID" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  echo "Error: --run-id must be non-empty and match ^[A-Za-z0-9._:-]+$ (got ${#RUN_ID} chars)"
  exit 1
fi

# Handed to xcodebuild by Examples/SimpleAwsDemo/Makefile, which re-exports them with the
# TEST_RUNNER_ prefix xcodebuild needs to reach the UI test runner (and from there the app).
export AWS_OTEL_CONTRACT_EXPORT_ENDPOINT="$ENDPOINT"
export AWS_OTEL_CONTRACT_REGION="$REGION"
export AWS_OTEL_CONTRACT_APP_MONITOR_ID="$APP_MONITOR_ID"
export AWS_OTEL_CONTRACT_RUN_ID="$RUN_ID"

echo "Running contract tests for $DESTINATION"
# Values are deliberately not echoed: the endpoint and app monitor id are secrets in CI.
if [[ "$HERMETIC" == true ]]; then
  echo "Mode: hermetic (local AwsOtelUI server, output assertions enabled)"
else
  echo "Mode: real endpoint (no local AwsOtelUI server, output assertions skipped)"
fi
# The run id is not a secret (it is a GitHub run id) and printing it is what lets a human match a
# failed fetch step back to the put step, so it is echoed on purpose.
if [[ -n "$RUN_ID" ]]; then
  echo "Correlation key: aws.otel.contract.run.id=$RUN_ID"
else
  echo "Correlation key: none (no --run-id supplied)"
fi

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cleanup function
cleanup() {
  echo "Cleaning up processes..."
  # Kill any processes using port 3000 (AwsOtelUI)
  lsof -ti:3000 | xargs kill -9 2>/dev/null || true
  # Kill any processes using port 8181 (MockEndpoint)
  lsof -ti:8181 | xargs kill -9 2>/dev/null || true
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

# Start MockEndpoint server
echo "Starting MockEndpoint server..."
cd "$PROJECT_ROOT/Tests/ContractTests/MockEndpoint"
node server.js &
MOCK_SERVER_PID=$!
sleep 2

# Verify MockEndpoint server is running
echo "Verifying MockEndpoint server..."
if ! bash test.sh; then
  echo "Error: MockEndpoint server verification failed"
  kill $MOCK_SERVER_PID 2>/dev/null || true
  exit 1
fi
echo "MockEndpoint server verified successfully"

# Start AwsOtelUI server (hermetic mode only — in real-endpoint mode nothing exports to :3000)
if [[ "$HERMETIC" == true ]]; then
  echo "Starting AwsOtelUI server..."
  cd "$PROJECT_ROOT/Examples/AwsOtelUI"
  npm i
  npm start &
  SERVER_PID=$!
  sleep 5
else
  echo "Skipping AwsOtelUI server: telemetry is exported to the supplied endpoint."
fi

# Generate spans and logs
echo "Generating spans and logs for $DESTINATION..."
cd "$PROJECT_ROOT/Examples/SimpleAwsDemo"

# Build and run the app with contract test mode
case $DESTINATION in
  ios)
    make contract-test-generate-data-$DESTINATION
    ;;
esac

# Verify contracts. The assertions in Tests/ContractTests parse the OTLP payloads AwsOtelUI dumped
# to Examples/AwsOtelUI/out, and against a real data plane nothing is written locally — so this
# script cannot run them itself in that mode. It does not follow that they are skipped: the
# put-to-get workflow runs the *same* assertions a step later, after
# scripts/verify-put-to-get.sh has fetched this run's telemetry back out of the app monitor's
# vended CloudWatch Logs group and rebuilt those two files from it. The suite is unaware of the
# difference, which is the point.
if [[ "$HERMETIC" == true ]]; then
  # List generated files
  echo "Generated files:"
  ls -al "$PROJECT_ROOT/Examples/AwsOtelUI/out"

  cd "$PROJECT_ROOT"
  swift test --filter ContractTests
else
  echo "Export complete. The assertions run separately in this mode: nothing is written to"
  echo "Examples/AwsOtelUI/out locally, so the caller fetches the telemetry back from the"
  echo "destination (scripts/verify-put-to-get.sh) and runs Tests/ContractTests against that."
fi

echo "Contract tests completed successfully!"