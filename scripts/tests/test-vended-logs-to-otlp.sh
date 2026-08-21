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

# Assert on what actually discriminates the two files. `eventName` is never emitted by the span
# path under any input, so asserting its absence from spans cannot fail; the real invariant is that
# everything in traces.jsonl carries the span-only fields and everything in logs.jsonl does not.
check "log records are not misrouted into traces.jsonl" "True" "$PRELUDE
print(all({'startTimeUnixNano', 'endTimeUnixNano', 'kind'} <= set(sp) for _, _, sp in spans)
      and not any('startTimeUnixNano' in lr for _, _, lr in records))"

echo "--- input shapes ---"

# The fetch step queries with `--query 'events[*].message' --output json`, which yields a bare
# JSON array of message strings rather than the full filter-log-events document. That projection
# is deliberate: `--output text` is tab-delimited, and vended messages may contain newlines, so
# rows cannot be split reliably. Both shapes must be accepted.
MESSAGES_FILE="$WORK_DIR/messages.json"
python3 - "$FIXTURE" "$MESSAGES_FILE" <<'PYMSG'
import json, sys
with open(sys.argv[1]) as handle:
    document = json.load(handle)
with open(sys.argv[2], "w") as handle:
    json.dump([event["message"] for event in document["events"]], handle)
PYMSG

LOGS_OUT="$WORK_DIR/m-logs.jsonl"
TRACES_OUT="$WORK_DIR/m-traces.jsonl"
"$TRANSFORM" --run-id run-a-1 --logs-out "$LOGS_OUT" --traces-out "$TRACES_OUT" "$MESSAGES_FILE" \
  > /dev/null 2>&1
check_status "accepts a bare array of message strings" 0 "$?"

check "an array of messages yields the same records as the full document" "3 2" "$PRELUDE
print(len(spans), len(records))"

echo "--- hostile input: the log group is a publicly writable, shared target ---"

# The target app monitor carries a public resource-based policy, so anyone holding its id can write
# whatever they like into the log group this reads. None of it may be able to take the run down:
# a single planted `42` turning every future run red — and blaming ingestion while doing it — is a
# denial of service on this workflow. The same hardening covers the data plane vending a record
# shaped differently from the ones this transform was built against.
HOSTILE_FILE="$WORK_DIR/hostile.json"
python3 - "$HOSTILE_FILE" <<'PYHOSTILE'
import json
import sys


def span(**overrides):
    record = {
        "resource": {"attributes": {"aws.otel.contract.run.id": "run-a-1"}},
        "scope": {"name": "software.amazon.opentelemetry.appstart", "version": ""},
        "traceId": "cb7b84a7d7be05e797a05a41ed10a7ef",
        "spanId": "31d6cfe0d16ae931",
        "name": "AppStart",
        "kind": "INTERNAL",
        "startTimeUnixNano": 1787340061523443968,
        "endTimeUnixNano": 1787340064949510144,
        "attributes": {},
        "status": {"code": "UNSET"},
    }
    record.update(overrides)
    return record


messages = [
    # Valid JSON, but not an object. Every one of these used to reach `.get` and crash.
    "42",
    '"hello"',
    "null",
    "[]",
    "true",
    # Object-shaped, but with pieces this transform assumes are dicts/strings.
    json.dumps(span(name="int-status", status={"code": 2})),
    json.dumps(span(name="list-resource", resource=[])),
    json.dumps(span(name="string-attributes", attributes="not-a-map")),
    # A span vended without `name`. The data plane does not guarantee one, and a nameless span
    # belongs in traces.jsonl regardless of whether it is nameable.
    json.dumps({key: value for key, value in span().items() if key != "name"}),
    # And one entirely ordinary record, so a crash cannot hide behind an empty result.
    json.dumps(span(name="Healthy")),
]
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(messages, handle)
PYHOSTILE

LOGS_OUT="$WORK_DIR/h-logs.jsonl"
TRACES_OUT="$WORK_DIR/h-traces.jsonl"
OUT=$("$TRANSFORM" --run-id run-a-1 --logs-out "$LOGS_OUT" --traces-out "$TRACES_OUT" \
  "$HOSTILE_FILE" 2>&1)
check_status "survives hostile and unexpected records" 0 "$?"

check "keeps every usable span, including the nameless one" \
  "['', 'Healthy', 'int-status', 'string-attributes']" "$PRELUDE
print(sorted(sp['name'] for _, _, sp in spans))"

check "a nameless span still goes to traces.jsonl, not logs.jsonl" "True" "$PRELUDE
print(len(records) == 0)"

check "stringifies a non-string status code instead of crashing on it" "2" "$PRELUDE
print(span_named('int-status')[0]['status']['code'])"

# A record whose `resource` is not a map cannot carry the correlation key, so the run-id filter
# drops it. What matters is that the filter drops it rather than an exception taking the run down.
check "drops a record whose resource cannot carry the correlation key" "True" "$PRELUDE
print(not span_named('list-resource'))"

check "treats non-dict attributes as empty rather than dropping a real record" "[]" "$PRELUDE
print(span_named('string-attributes')[0]['attributes'])"

if grep -q "5 event(s)" <<<"$OUT"; then
  PASSED=$(( PASSED + 1 )); echo "  PASS  reports how many events it had to skip"
else
  FAILED=$(( FAILED + 1 )); echo "  FAIL  reports how many events it had to skip (got: $OUT)"
fi

if grep -qE "hello|\bnot-a-map\b|cb7b84a7" <<<"$OUT"; then
  FAILED=$(( FAILED + 1 )); echo "  FAIL  never prints a skipped record's content (got: $OUT)"
else
  PASSED=$(( PASSED + 1 )); echo "  PASS  never prints a skipped record's content"
fi

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

# 2 is argparse's usage code, and it must stay distinct from both 1 ("nothing matched") and 3
# ("this tool broke"): the caller keys its behaviour off which of the three it gets.
"$TRANSFORM" --logs-out "$WORK_DIR/x.jsonl" --traces-out "$WORK_DIR/y.jsonl" "$FIXTURE" >/dev/null 2>&1
check_status "exits with argparse's usage code when --run-id is missing" 2 "$?"

# An input this script cannot read at all is a bug in the tooling, not slow delivery. It must be
# distinguishable from "nothing matched yet", which the fetch loop treats as "keep polling" — a
# crash reported as exit 1 makes a broken transform look like an ingestion outage for the whole
# budget, and then blames the SDK in the timeout message.
echo '42' > "$WORK_DIR/unreadable.json"
OUT=$("$TRANSFORM" --run-id run-a-1 --logs-out "$WORK_DIR/u-logs.jsonl" \
  --traces-out "$WORK_DIR/u-traces.jsonl" "$WORK_DIR/unreadable.json" 2>&1)
check_status "exits 3 — not 1 — when the input cannot be read at all" 3 "$?"
if grep -q "Traceback" <<<"$OUT"; then
  PASSED=$(( PASSED + 1 )); echo "  PASS  prints the traceback so the caller can surface it"
else
  FAILED=$(( FAILED + 1 )); echo "  FAIL  prints the traceback so the caller can surface it (got: $OUT)"
fi

echo
echo "=== $PASSED passed, $FAILED failed ==="
[[ $FAILED -eq 0 ]]
