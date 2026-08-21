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

# The other two things the AWS CLI quotes back at you in an AccessDenied message. The account id is
# named as a secret in this workflow's requirements, and GitHub's own masking does not cover it: the
# registered secret is the whole role ARN, and masking is substring-exact, so a bare account id
# inside a *different* ARN (the log group's) comes through in the clear.
SECRET_ACCOUNT_ID="000000000000"
SECRET_ROLE_NAME="PutToGetContractTestRole"

WORK_DIR=$(mktemp -d)
STUB_DIR="$WORK_DIR/bin"
mkdir -p "$STUB_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT

# Point the script at a scratch output directory. Its default is Examples/AwsOtelUI/out, which is
# where a local hermetic contract-test run leaves its artifacts — running these tests must not
# destroy them.
OUT_DIR="$WORK_DIR/out"
LOGS_OUT="$OUT_DIR/logs.jsonl"
TRACES_OUT="$OUT_DIR/traces.jsonl"

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

# Same as assert_contains, but for claims about a *value* the script computed rather than a phrase it
# always prints. A literal grep for a static label passes whatever the value is, so the assertion
# survives the computation being deleted — which is exactly how a broken counter stays green.
assert_matches() {
  local description="$1" pattern="$2" haystack="$3"
  if grep -qE -e "$pattern" <<<"$haystack"; then
    pass "$description"
  else
    fail "$description" "output did not match: $pattern"
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
#   poison   — the full delivery plus a planted non-object message
#   junk     — a response the transform cannot read at all
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
  poison)   python3 "$STUB_HELPER" "$FIXTURE_PATH" all poison ;;
  junk)     echo '42' ;;
  none)     echo '[]' ;;
  denied)
    # Verbatim shape of a real logs:FilterLogEvents denial: the caller's assumed-role ARN, the role
    # and session names, and the account id twice (once in each ARN).
    echo "An error occurred (AccessDeniedException) when calling the FilterLogEvents operation:" \
      "User: arn:aws:sts::000000000000:assumed-role/PutToGetContractTestRole/GitHubActions-PutToGet" \
      "is not authorized to perform: logs:FilterLogEvents on resource:" \
      "arn:aws:logs:us-east-1:000000000000:log-group:$AWS_OTEL_CONTRACT_LOG_GROUP:*" >&2
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
# Anyone holding the app monitor id can write to this log group, so a message that is valid JSON but
# not an object is reachable input, not a hypothetical.
if len(sys.argv) > 3 and sys.argv[3] == "poison":
    messages.insert(0, "42")
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
  AWS_OTEL_CONTRACT_OUT_DIR="$OUT_DIR" \
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
#
# "Unchanged across N consecutive polls" means N *comparisons* against a previous count, so it needs
# N+1 polls. A first poll has nothing to compare against and must not count as a stable one: with 2
# required, the real run's attempt 2 showed a count that had held for a single quiet interval and
# then grew anyway. So `full` repeated must take at least 3 calls, not 2.
OUTPUT=$(run_verify "full full")
if [[ "$(aws_call_count)" -ge 3 ]]; then
  pass "counts stability as intervals between polls, not as the first poll itself"
else
  fail "counts stability as intervals between polls, not as the first poll itself" \
    "only $(aws_call_count) call(s) to filter-log-events"
fi
assert_contains "reports zero stable intervals on the first poll, having nothing to compare to" \
  "Attempt 1: 5 record(s) so far (3 span(s), 2 log record(s)), unchanged over 0 poll(s)" "$OUTPUT"

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

# A run that only ever gets throttled looks identical to a run where nothing was ever delivered:
# both end with zero records. The timeout message must not diagnose the second when it was the first.
OUTPUT=$(run_verify "transient" --timeout-seconds 4)
assert_status "fails when every fetch is throttled" 1 "$?"
assert_matches "counts the transient failures so a throttled run is not read as no delivery" \
  "transient fetch failures: [1-9][0-9]* of [1-9][0-9]* attempt" "$OUTPUT"

# And the other direction, which is what makes the count mean anything: a run where every fetch
# succeeded must report zero, not just "some number".
OUTPUT=$(run_verify "none" --timeout-seconds 4)
assert_contains "reports zero transient failures when every fetch succeeded" \
  "transient fetch failures: 0 of" "$OUTPUT"

echo "--- a shared, publicly writable log group cannot be trusted to hold only our records ---"

# The app monitor carries a public resource-based policy, so anyone holding its id can write into the
# group this reads. A planted non-object message must not be able to red the workflow permanently.
OUTPUT=$(run_verify "poison poison poison")
assert_status "succeeds when a third party has planted an unusable message" 0 "$?"
assert_contains "still rebuilds the run's own records" "3 span(s), 2 log record(s)" "$OUTPUT"

# The other side of the same coin: if the transform itself breaks, that is a tooling bug and must be
# reported as one immediately. Treating it as "nothing matched yet" burns the whole budget and then
# blames ingestion for a Python error.
OUTPUT=$(run_verify "junk" --timeout-seconds 4)
assert_status "fails when the rebuild step breaks outright" 1 "$?"
assert_contains "blames the rebuild step rather than delivery" \
  "rebuild step failed" "$OUTPUT"
if [[ "$(aws_call_count)" == "1" ]]; then
  pass "does not keep polling after the rebuild step breaks"
else
  fail "does not keep polling after the rebuild step breaks" "$(aws_call_count) call(s)"
fi

echo "--- the log group name is a secret on every path, including the failure paths ---"

# `junk` and `poison` are in this list because they are the two paths that print the rebuild step's
# own output (`cat` of the transform's stdout), which is the one channel in this script that forwards
# text it did not compose itself. No leak has been demonstrated through it — the transform is never
# handed the log group, and a Python traceback carries no data values — so this is a regression guard
# on a plausible future one, not a fix for a known leak.
for SCENARIO in "full full" "partial" "none" "denied" "notfound" "transient transient full full" \
  "junk" "poison poison poison"; do
  OUTPUT=$(run_verify "$SCENARIO" --timeout-seconds 4)
  assert_absent "never echoes the log group name (scenario: $SCENARIO)" \
    "$SECRET_LOG_GROUP" "$OUTPUT"
done

# The redaction has to survive the CLI's own error text, which quotes the group back at us.
OUTPUT=$(run_verify "denied")
assert_contains "redacts the log group out of the CLI's error text" \
  "<CONTRACT_TEST_LOG_GROUP>" "$OUTPUT"

# AccessDenied is the worst case for leakage: the CLI answers with the caller's assumed-role ARN and
# the resource ARN, so the account id appears twice and the role name once. Substituting the known
# secret is not enough — the redaction has to be structural, because these values are never passed to
# this script and so cannot be matched against anything it holds.
assert_absent "does not leak the account id out of a denial message" \
  "$SECRET_ACCOUNT_ID" "$OUTPUT"
assert_absent "does not leak the IAM role name out of a denial message" \
  "$SECRET_ROLE_NAME" "$OUTPUT"
# Redaction must keep the message *actionable*, so the CLI's own diagnosis has to survive it. Do not
# assert on `logs:FilterLogEvents` here: this script prints that string itself, as static advice,
# whatever the CLI said — so the assertion passes even if redacted_stderr emits nothing at all. These
# three phrases exist only in the CLI's stderr, so they can only appear if it was actually printed.
assert_contains "keeps the CLI's own diagnosis rather than suppressing it" \
  "is not authorized to perform" "$OUTPUT"
assert_contains "keeps the error code the CLI reported" "AccessDeniedException" "$OUTPUT"
assert_contains "leaves a redacted ARN still recognisable as an ARN" \
  "assumed-role/<PRINCIPAL>" "$OUTPUT"

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

# The unrecognised-option path echoes the offending argument, and the most likely way to reach it is
# writing a real invocation with `=` instead of a space: `--log-group=<the secret>` is one token, so
# the whole secret is what gets echoed. This is a workflow-authoring typo away, and the output of a
# failed CI step is exactly where nobody expects to find a secret.
OUTPUT=$(AWS_OTEL_CONTRACT_REGION=us-east-1 AWS_OTEL_CONTRACT_RUN_ID=abc \
  "$VERIFY" "--log-group=$SECRET_LOG_GROUP" 2>&1)
assert_status "rejects an unknown option" 1 "$?"
assert_contains "names the unrecognised option" "Unknown option: --log-group" "$OUTPUT"
assert_absent "does not echo an option's value while rejecting it" "$SECRET_LOG_GROUP" "$OUTPUT"

rm -rf "$OUT_DIR"

echo
echo "=== $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
