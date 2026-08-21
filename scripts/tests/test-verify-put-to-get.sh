#!/bin/bash

# Tests scripts/verify-put-to-get.sh — the fetch half of the put-to-get contract test.
#
# The AWS CLI is stubbed, so this runs anywhere and needs no credentials. What it exercises is the
# part that has no other safety net:
#
#   * polling to *quiescence* rather than to first match. RUM delivers a run's telemetry in several
#     batches, and Tests/ContractTests asserts exact counts, so returning early hands the suite a
#     partial set and produces count failures that look like product bugs.
#   * never leaking the log group name. It is a CI secret (it embeds the app monitor id) and must
#     stay out of the output on the failure paths too, which are exactly the paths nobody reads
#     until something has already gone wrong.
#   * failing loudly instead of leaving empty output files behind. OtlpFileParser swallows log
#     decode failures and only prints trace decode failures, so silence here becomes a wall of
#     assertion failures over there.
#
# Run: ./scripts/tests/test-verify-put-to-get.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFY="$PROJECT_ROOT/scripts/verify-put-to-get.sh"
FIXTURE="$SCRIPT_DIR/fixtures/vended-log-events.json"

# The fixture holds 3 spans and 2 log records for run-a-1 (plus another run's records and a
# third-party record, which must be filtered out), so a complete "delivery" here is 5 records.
FIXTURE_RUN_ID="run-a-1"
FIXTURE_RECORD_COUNT=5

# A stand-in for the real secret. Every assertion about non-leakage greps for this exact string.
SECRET_LOG_GROUP="/aws/vendedlogs/RUMService_SECRETMONITORID12345"

OUT_DIR="$PROJECT_ROOT/Examples/AwsOtelUI/out"
LOGS_OUT="$OUT_DIR/logs.jsonl"
TRACES_OUT="$OUT_DIR/traces.jsonl"

WORK_DIR=$(mktemp -d)
STUB_DIR="$WORK_DIR/bin"
mkdir -p "$STUB_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

PASSED=0
FAILED=0

pass() { PASSED=$(( PASSED + 1 )); echo "  PASS  $1"; }
fail() {
  FAILED=$(( FAILED + 1 ))
  echo "  FAIL  $1"
  [[ $# -gt 1 ]] && echo "        $2"
}

assert_status() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$description"
  else
    fail "$description" "expected exit $expected, got $actual"
  fi
}

assert_contains() {
  local description="$1" needle="$2" haystack="$3"
  if grep -qF -e "$needle" <<<"$haystack"; then
    pass "$description"
  else
    fail "$description" "output did not mention: $needle"
  fi
}

assert_absent() {
  local description="$1" needle="$2" haystack="$3"
  if grep -qF -e "$needle" <<<"$haystack"; then
    fail "$description" "output leaked: $needle"
  else
    pass "$description"
  fi
}

# Builds the `aws` stub. Each invocation prints the messages named by the Nth word of $SCHEDULE
# (the last word repeats once the schedule runs out) and appends a line to a call log.
#
#   full     — every record the fixture holds for this run
#   partial  — only the first two
#   none     — an empty result
#   denied / notfound / transient — the corresponding CLI failure
install_aws_stub() {
  cat > "$STUB_DIR/aws" <<'STUB'
#!/bin/bash
echo "$*" >> "$AWS_CALL_LOG"
CALL_NUMBER=$(grep -c '' < "$AWS_CALL_LOG")
read -r -a STEPS <<< "$SCHEDULE"
STEP="${STEPS[$(( CALL_NUMBER - 1 ))]:-${STEPS[$(( ${#STEPS[@]} - 1 ))]}}"
case "$STEP" in
  full)     python3 "$STUB_HELPER" "$FIXTURE_PATH" all ;;
  partial)  python3 "$STUB_HELPER" "$FIXTURE_PATH" 2 ;;
  none)     echo '[]' ;;
  denied)
    echo "An error occurred (AccessDeniedException) when calling the FilterLogEvents operation:" \
      "User is not authorized to perform: logs:FilterLogEvents on resource:" \
      "arn:aws:logs:us-east-1:000000000000:log-group:$AWS_OTEL_CONTRACT_LOG_GROUP" >&2
    exit 254
    ;;
  notfound)
    echo "An error occurred (ResourceNotFoundException) when calling the FilterLogEvents" \
      "operation: The specified log group does not exist: $AWS_OTEL_CONTRACT_LOG_GROUP" >&2
    exit 254
    ;;
  transient)
    echo "An error occurred (ThrottlingException) when calling the FilterLogEvents operation:" \
      "Rate exceeded for $AWS_OTEL_CONTRACT_LOG_GROUP" >&2
    exit 254
    ;;
esac
STUB
  chmod +x "$STUB_DIR/aws"

  # Projects the fixture the way the real query does: `--query 'events[*].message' --output json`.
  cat > "$WORK_DIR/project.py" <<'HELPER'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    messages = [event["message"] for event in json.load(handle)["events"]]
if sys.argv[2] != "all":
    messages = messages[: int(sys.argv[2])]
print(json.dumps(messages))
HELPER
}

# Runs the script under the stub. First argument is the schedule; the rest are extra flags.
run_verify() {
  local schedule="$1"
  shift
  rm -f "$WORK_DIR/aws-calls.txt"
  : > "$WORK_DIR/aws-calls.txt"
  PATH="$STUB_DIR:$PATH" \
  SCHEDULE="$schedule" \
  AWS_CALL_LOG="$WORK_DIR/aws-calls.txt" \
  STUB_HELPER="$WORK_DIR/project.py" \
  FIXTURE_PATH="$FIXTURE" \
  AWS_OTEL_CONTRACT_LOG_GROUP="$SECRET_LOG_GROUP" \
  AWS_OTEL_CONTRACT_REGION="us-east-1" \
  AWS_OTEL_CONTRACT_RUN_ID="$FIXTURE_RUN_ID" \
    "$VERIFY" --min-records "$FIXTURE_RECORD_COUNT" --poll-interval-seconds 1 "$@" 2>&1
}

aws_call_count() { grep -c '' < "$WORK_DIR/aws-calls.txt"; }

install_aws_stub
rm -rf "$OUT_DIR"

echo "=== verify-put-to-get: fetches a run's telemetry and rebuilds OTLP for the contract tests ==="

# Stale output from an earlier run. Not truncating it would let the contract tests assert against
# the previous run's telemetry and report a false green.
mkdir -p "$OUT_DIR"
echo '{"resourceLogs":[{"stale":true}]}' > "$LOGS_OUT"
echo '{"resourceSpans":[{"stale":true}]}' > "$TRACES_OUT"

OUTPUT=$(run_verify "full full")
assert_status "exits 0 once delivery is complete and quiescent" 0 "$?"
assert_contains "reports the record counts it rebuilt" "3 span(s), 2 log record(s)" "$OUTPUT"
assert_contains "confirms the rebuilt files parse as OTLP" "logs.jsonl: 2 line(s), 2 logRecords" "$OUTPUT"
assert_contains "reports a put-to-queryable latency" "put -> fully queryable" "$OUTPUT"

if [[ -s "$TRACES_OUT" ]] && ! grep -qF 'stale' "$TRACES_OUT" "$LOGS_OUT"; then
  pass "truncates stale output files rather than appending to them"
else
  fail "truncates stale output files rather than appending to them"
fi

if [[ "$(grep -c '' < "$TRACES_OUT")" == "3" && "$(grep -c '' < "$LOGS_OUT")" == "2" ]]; then
  pass "writes the run's records to the paths OTLPResolver reads"
else
  fail "writes the run's records to the paths OTLPResolver reads" \
    "traces=$(grep -c '' < "$TRACES_OUT") logs=$(grep -c '' < "$LOGS_OUT")"
fi

echo "--- quiescence: the suite asserts exact counts, so partial delivery must not pass ---"

# Everything is already there on the first poll, but one poll cannot distinguish "complete" from
# "the first of several batches", so the script must poll again and see the count hold.
OUTPUT=$(run_verify "full full")
if [[ "$(aws_call_count)" -ge 2 ]]; then
  pass "polls again to confirm the count is stable before passing"
else
  fail "polls again to confirm the count is stable before passing" \
    "only $(aws_call_count) call(s) to filter-log-events"
fi

# Records trickle in. The script must wait for the full set, not return on the first batch.
OUTPUT=$(run_verify "partial partial full full")
assert_status "waits through a partial batch for the rest of the delivery" 0 "$?"
assert_contains "reports the partial count while it waits" "2 record(s) so far" "$OUTPUT"
if [[ "$(grep -c '' < "$TRACES_OUT")" == "3" ]]; then
  pass "ends with the complete set, not the partial one"
else
  fail "ends with the complete set, not the partial one" "traces=$(grep -c '' < "$TRACES_OUT")"
fi

# Delivery stalls below the floor. A stable-but-short count must fail, and say so as a shortfall —
# handing 2 of 5 records to the contract tests would surface as unrelated count assertions.
OUTPUT=$(run_verify "partial" --timeout-seconds 4)
assert_status "fails when delivery stalls below the completeness floor" 1 "$?"
assert_contains "names the shortfall rather than reporting a bare timeout" \
  "records found:    2 (2 span(s), 0 log record(s)); needed >= 5" "$OUTPUT"
assert_contains "explains that a partial delivery means records were accepted" \
  "Delivery is partial" "$OUTPUT"

OUTPUT=$(run_verify "none" --timeout-seconds 4)
assert_status "fails when nothing arrives at all" 1 "$?"
assert_contains "names the correlation key it searched for" \
  "aws.otel.contract.run.id=$FIXTURE_RUN_ID" "$OUTPUT"
assert_contains "distinguishes 'nothing arrived' from 'partial delivery'" \
  "Nothing at all arrived" "$OUTPUT"

echo "--- fetch failures are classified, not retried blindly ---"

OUTPUT=$(run_verify "denied")
assert_status "fails fast on AccessDenied" 1 "$?"
assert_contains "says retrying will not help" "retrying will not help" "$OUTPUT"
assert_contains "names the stream-qualified ARN the role needs" \
  "logs:FilterLogEvents on the log-group ARN" "$OUTPUT"
if [[ "$(aws_call_count)" == "1" ]]; then
  pass "does not burn the budget retrying a permissions error"
else
  fail "does not burn the budget retrying a permissions error" "$(aws_call_count) call(s)"
fi

OUTPUT=$(run_verify "notfound")
assert_status "fails fast on ResourceNotFound" 1 "$?"
assert_contains "points at the secrets that name the group" "CONTRACT_TEST_LOG_GROUP" "$OUTPUT"

OUTPUT=$(run_verify "transient transient full full")
assert_status "retries a transient CLI error and then succeeds" 0 "$?"
assert_contains "says it will retry" "failed transiently; will retry" "$OUTPUT"

echo "--- the log group name is a secret on every path, including the failure paths ---"

for SCENARIO in "full full" "partial" "none" "denied" "notfound" "transient transient full full"; do
  OUTPUT=$(run_verify "$SCENARIO" --timeout-seconds 4)
  assert_absent "never echoes the log group name (scenario: $SCENARIO)" \
    "$SECRET_LOG_GROUP" "$OUTPUT"
done

# The redaction has to survive the CLI's own error text, which quotes the group back at us.
OUTPUT=$(run_verify "denied")
assert_contains "redacts the log group out of the CLI's error text" \
  "<CONTRACT_TEST_LOG_GROUP>" "$OUTPUT"

# Vended events carry the app monitor id and, because the monitor is a public write target,
# arbitrary third-party content. None of it belongs in a CI log.
OUTPUT=$(run_verify "full full")
assert_absent "never prints a fetched event's contents" \
  "00000000-0000-0000-0000-000000000000" "$OUTPUT"
assert_absent "never prints another run's correlation key" "run-b-7" "$OUTPUT"

echo "--- argument validation ---"

OUTPUT=$(AWS_OTEL_CONTRACT_LOG_GROUP="$SECRET_LOG_GROUP" AWS_OTEL_CONTRACT_REGION=us-east-1 \
  "$VERIFY" 2>&1)
assert_status "requires --run-id" 1 "$?"
assert_absent "does not echo the log group while rejecting arguments" "$SECRET_LOG_GROUP" "$OUTPUT"

OUTPUT=$(AWS_OTEL_CONTRACT_REGION=us-east-1 AWS_OTEL_CONTRACT_RUN_ID=abc "$VERIFY" 2>&1)
assert_status "requires --log-group" 1 "$?"

OUTPUT=$(AWS_OTEL_CONTRACT_LOG_GROUP="$SECRET_LOG_GROUP" AWS_OTEL_CONTRACT_RUN_ID='bad key!' \
  AWS_OTEL_CONTRACT_REGION=us-east-1 "$VERIFY" 2>&1)
assert_status "rejects a run id the put side could not have stamped" 1 "$?"

rm -rf "$OUT_DIR"

echo
echo "=== $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
