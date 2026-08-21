#!/bin/bash

# Tests scripts/vended-logs-to-otlp.py — the "get" side of the put-to-get contract test.
#
# That script's whole job is to turn the events a CloudWatch RUM app monitor vends into
# CloudWatch Logs back into the two OTLP/JSON files Tests/ContractTests already parses
# (Examples/AwsOtelUI/out/{logs,traces}.jsonl), so the *same* assertions that guard the hermetic
# run also guard a real round trip. Everything asserted here was derived from real vended events;
# scripts/tests/fixtures/vended-log-events.json is a redacted copy of that shape.
#
# Run: ./scripts/tests/test-vended-logs-to-otlp.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRANSFORM="$PROJECT_ROOT/scripts/vended-logs-to-otlp.py"
FIXTURE="$SCRIPT_DIR/fixtures/vended-log-events.json"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

PASSED=0
FAILED=0

# Runs a python3 expression against the produced files. The expression must print exactly the
# expected string; anything else (including a traceback) is a failure.
check() {
  local description="$1" expected="$2" expression="$3"
  local actual
  actual=$(LOGS_OUT="$LOGS_OUT" TRACES_OUT="$TRACES_OUT" python3 -c "$expression" 2>&1)
  if [[ "$actual" == "$expected" ]]; then
    PASSED=$(( PASSED + 1 ))
    echo "  PASS  $description"
  else
    FAILED=$(( FAILED + 1 ))
    echo "  FAIL  $description"
    echo "        expected: $expected"
    echo "        actual:   $actual"
  fi
}

check_status() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASSED=$(( PASSED + 1 ))
    echo "  PASS  $description"
  else
    FAILED=$(( FAILED + 1 ))
    echo "  FAIL  $description (expected exit $expected, got $actual)"
  fi
}

# Shared preamble for the python checks: load both files as lists of parsed JSONL documents, and
# expose the flattened span/log-record lists the contract tests work with.
PRELUDE=$(cat <<'PYPRE'
import json, os
def load(path):
    with open(path) as handle:
        return [json.loads(line) for line in handle if line.strip()]
logs_docs = load(os.environ["LOGS_OUT"])
traces_docs = load(os.environ["TRACES_OUT"])
spans = [(rs["resource"], ss["scope"], sp)
         for doc in traces_docs for rs in doc["resourceSpans"]
         for ss in rs["scopeSpans"] for sp in ss["spans"]]
records = [(rl["resource"], sl["scope"], lr)
           for doc in logs_docs for rl in doc["resourceLogs"]
           for sl in rl["scopeLogs"] for lr in sl["logRecords"]]
def attr(owner, key):
    return next((a["value"] for a in owner["attributes"] if a["key"] == key), None)
def span_named(name):
    return [sp for _, _, sp in spans if sp["name"] == name]
PYPRE
)

echo "=== vended-logs-to-otlp: transforms a run's vended events into OTLP JSONL ==="

LOGS_OUT="$WORK_DIR/logs.jsonl"
TRACES_OUT="$WORK_DIR/traces.jsonl"

# Stale content from a previous run. The transform must truncate: leaving it would let the
# contract tests assert against the *previous* run's telemetry and report a false green.
echo '{"resourceLogs":[{"stale":true}]}' > "$LOGS_OUT"
echo '{"resourceSpans":[{"stale":true}]}' > "$TRACES_OUT"

"$TRANSFORM" --run-id run-a-1 --logs-out "$LOGS_OUT" --traces-out "$TRACES_OUT" "$FIXTURE" \
  > "$WORK_DIR/stdout.txt" 2>&1
check_status "exits 0 when the run's records are present" 0 "$?"

check "keeps only this run's spans" "3" "$PRELUDE
print(len(spans))"

check "keeps only this run's log records" "2" "$PRELUDE
print(len(records))"

check "drops records carrying another run's correlation key" "['run-a-1']" "$PRELUDE
print(sorted({attr(r, 'aws.otel.contract.run.id')['stringValue'] for r, _, _ in spans + records}))"

check "every output line is a standalone JSON document" "True" "$PRELUDE
print(len(traces_docs) == 3 and len(logs_docs) == 2)"

check "no stale content survives" "False" "$PRELUDE
print(any('stale' in json.dumps(d) for d in logs_docs + traces_docs))"

echo "--- resource: vended attribute map becomes an OTLP attribute array ---"

check "resource attributes are a keyed array" "True" "$PRELUDE
print(all(isinstance(r['attributes'], list) and all({'key','value'} <= set(a) for a in r['attributes']) for r, _, _ in spans))"

check "service.name survives" "SimpleAwsDemo" "$PRELUDE
print(attr(spans[0][0], 'service.name')['stringValue'])"

check "scope name survives (the contract tests filter on it)" "['NSURLSession', 'software.amazon.opentelemetry.appstart']" "$PRELUDE
print(sorted({s['name'] for _, s, _ in spans}))"

echo "--- spans: protobuf-JSON conventions the parser expects ---"

check "timestamps are strings, not numbers" "True" "$PRELUDE
print(all(isinstance(sp['startTimeUnixNano'], str) and isinstance(sp['endTimeUnixNano'], str) for _, _, sp in spans))"

check "nanosecond precision is preserved exactly" "1787340061523443968" "$PRELUDE
print(span_named('AppStart')[0]['startTimeUnixNano'])"

check "span kind is the OTLP enum name" "['SPAN_KIND_CLIENT', 'SPAN_KIND_INTERNAL']" "$PRELUDE
print(sorted({sp['kind'] for _, _, sp in spans}))"

check "traceId and spanId stay hex" "True" "$PRELUDE
print(span_named('AppStart')[0]['traceId'] == 'cb7b84a7d7be05e797a05a41ed10a7ef')"

check "an errored span keeps its status code and message" "STATUS_CODE_ERROR 404" "$PRELUDE
s = [sp for sp in span_named('HTTP GET') if attr(sp, 'http.target')['stringValue'] == '/404'][0]
print(s['status']['code'], s['status']['message'])"

# NetworkTests asserts XCTAssertNil(span200?.status?.message). Synthesizing an empty string here
# would turn that into a failure, so an absent message must stay absent.
check "an unset span has no status message at all" "True" "$PRELUDE
s = [sp for sp in span_named('HTTP GET') if attr(sp, 'http.target')['stringValue'] == '/200'][0]
print(s['status']['code'] == 'STATUS_CODE_UNSET' and 'message' not in s['status'])"

echo "--- attributes: the vended JSON's native types map onto OTLP AnyValue ---"

check "integers become intValue *strings*" "200" "$PRELUDE
s = [sp for sp in span_named('HTTP GET') if attr(sp, 'http.target')['stringValue'] == '/200'][0]
print(attr(s, 'http.status_code')['intValue'])"

check "doubles become doubleValue numbers" "355.719" "$PRELUDE
print(attr(span_named('AppStart')[0], 'process.memory.usage')['doubleValue'])"

# RUM vends a zero-valued double as 0.0. Typing it as an integer would make
# SystemMetricsTests' doubleValue lookup return nil on every record.
check "a zero double stays a double" "0.0" "$PRELUDE
print(attr(span_named('AppStart')[0], 'process.cpu.utilization')['doubleValue'])"

check "booleans become boolValue" "False" "$PRELUDE
print(attr(span_named('AppStart')[0], 'active_prewarm')['boolValue'])"

check "strings become stringValue" "cold" "$PRELUDE
print(attr(span_named('AppStart')[0], 'start.type')['stringValue'])"

echo "--- log records ---"

check "log records keep the top-level eventName" "['app.screen.view_did_appear', 'session.start']" "$PRELUDE
print(sorted(lr['eventName'] for _, _, lr in records))"

check "log timestamps are strings" "True" "$PRELUDE
print(all(isinstance(lr['timeUnixNano'], str) and isinstance(lr['observedTimeUnixNano'], str) for _, _, lr in records))"

check "log records are not misrouted into traces.jsonl" "True" "$PRELUDE
print(all('eventName' not in sp for _, _, sp in spans))"

echo "--- failure modes ---"

# A silent success on no data is the dangerous case: the contract tests would then run against
# two empty files, and the parser's failures would read as "the telemetry never arrived".
OUT=$("$TRANSFORM" --run-id no-such-run --logs-out "$WORK_DIR/e-logs.jsonl" \
  --traces-out "$WORK_DIR/e-traces.jsonl" "$FIXTURE" 2>&1)
check_status "exits non-zero when no record matches the run id" 1 "$?"
if grep -q "no-such-run" <<<"$OUT"; then
  PASSED=$(( PASSED + 1 )); echo "  PASS  names the run id it searched for"
else
  FAILED=$(( FAILED + 1 )); echo "  FAIL  names the run id it searched for (got: $OUT)"
fi

"$TRANSFORM" --logs-out "$WORK_DIR/x.jsonl" --traces-out "$WORK_DIR/y.jsonl" "$FIXTURE" >/dev/null 2>&1
check_status "exits non-zero when --run-id is missing" 2 "$?"

echo
echo "=== $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
