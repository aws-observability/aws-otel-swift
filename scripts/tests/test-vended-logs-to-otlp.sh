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

# Assert on the *identity* of what landed in each file, not on the key sets the two output builders
# literally construct. Asserting "every span has startTimeUnixNano" is tautological — the span
# builder always writes that key, whatever it was handed — and swapping `is_span`'s sense leaves such
# an assertion passing. What only correct routing can produce is span-shaped input keeping its span
# identity (the fixture's spans all carry spanId 31d662c216f6574c and its log records carry none) and
# log-shaped input keeping its eventName.
check "routes each record by its input shape, not by what the builders emit" "True" "$PRELUDE
print(len(spans) == 3 and len(records) == 2
      and all(sp['spanId'] == '31d662c216f6574c' for _, _, sp in spans)
      and all(lr['eventName'] in ('session.start', 'app.screen.view_did_appear') for _, _, lr in records))"

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
    # Not parseable at all, and specifically not parseable in a way that raises JSONDecodeError:
    # `json.loads` hits its recursion limit on deeply nested input and raises RecursionError. A guard
    # that names JSONDecodeError does not cover it, so this 4 KB message escapes the parse, becomes an
    # exit 3, and is read by the fetch step as "the rebuild step is broken" — permanently, because the
    # message stays in the log group for its whole retention. One planted write, every future run red.
    "[" * 2000 + "]" * 2000,
    # Object-shaped, but with pieces this transform assumes are dicts/strings.
    json.dumps(span(name="int-status", status={"code": 2})),
    json.dumps(span(name="list-resource", resource=[])),
    json.dumps(span(name="string-attributes", attributes="not-a-map")),
    # A span vended without `name`. The data plane does not guarantee one, and a nameless span
    # belongs in traces.jsonl regardless of whether it is nameable.
    json.dumps({key: value for key, value in span().items() if key != "name"}),
    # A non-finite double. `json.dumps` writes bare `NaN`, which is not JSON: Python's parser accepts
    # it, Swift's JSONDecoder rejects the whole line, and OtlpFileParser answers a trace decode
    # failure by printing the line's first 200 chars -- which is where the app monitor id sits, since
    # resource attributes are sorted. GitHub's masking is substring-exact, so even a truncated secret
    # prints in the clear. The transform must not be able to emit a line Swift cannot read.
    json.dumps(span(name="nan-double", attributes={"process.cpu.utilization": float("nan")})),
    # Every field the Swift parser declares as a non-optional String or Int, vended as something
    # else. Each one on its own is a whole-line decode failure, i.e. the same 200-char echo.
    json.dumps(
        span(
            name="typed",
            traceId=1,
            spanId=2,
            parentSpanId=3,
            kind=7,
            flags="4",
            droppedAttributesCount="5",
            status={"code": "ERROR", "message": 404},
            scope={"name": 5, "version": 6},
            events=[{"timeUnixNano": 1, "name": 2, "attributes": {}}],
        )
    ),
    json.dumps(span(name=99, spanId="deadbeefdeadbeef")),
    # The log-record side of the same problem.
    json.dumps(
        {
            "resource": {"attributes": {"aws.otel.contract.run.id": "run-a-1"}},
            "scope": {"name": "software.amazon.opentelemetry.session", "version": ""},
            "timeUnixNano": 1787340061523443968,
            "observedTimeUnixNano": 1787340061523443968,
            "eventName": 7,
            "severityText": 8,
            "severityNumber": "9",
            "flags": "0",
            "attributes": {},
        }
    ),
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
  "['', '99', 'Healthy', 'int-status', 'nan-double', 'string-attributes', 'typed']" "$PRELUDE
print(sorted(sp['name'] for _, _, sp in spans))"

check "a nameless span still goes to traces.jsonl, not logs.jsonl" "True" "$PRELUDE
print(len(records) == 1 and records[0][2]['eventName'] == '7')"

check "stringifies a non-string status code instead of crashing on it" "2" "$PRELUDE
print(span_named('int-status')[0]['status']['code'])"

# Everything below is about one property: nothing this script writes may fail to decode on the Swift
# side. OtlpFileParser answers a trace decode failure by printing the line's first 200 chars, and
# because resource attributes are sorted, the app monitor id is inside that window. A decode failure
# is therefore a secret leak, not just a lost record — and GitHub's masking will not catch it,
# because masking is substring-exact and the printed prefix truncates the value.

check "never writes a line Swift's JSONDecoder would reject (no bare NaN/Infinity)" "True" "$PRELUDE
def strict(path):
    with open(path) as handle:
        for line in handle:
            if line.strip():
                json.loads(line, parse_constant=lambda name: (_ for _ in ()).throw(ValueError(name)))
    return True
print(strict(os.environ['LOGS_OUT']) and strict(os.environ['TRACES_OUT']))"

check "a non-finite double becomes a string rather than invalid JSON" "nan" "$PRELUDE
print(attr(span_named('nan-double')[0], 'process.cpu.utilization')['stringValue'])"

# The Swift model, field for field: Span.traceId/spanId/name/kind/startTimeUnixNano/endTimeUnixNano
# are non-optional String; parentSpanId is String?; flags and droppedAttributesCount are Int?;
# Scope.name is decoded with `decode(String.self)` (required); SpanStatus.code/message are String?.
# `decodeIfPresent` throws on a type mismatch rather than yielding nil, so any one of these arriving
# as a number is a whole-line failure.
check "coerces every field the Swift parser types, on every record" "True" "$PRELUDE
SPAN_STR = ('traceId', 'spanId', 'parentSpanId', 'name', 'kind', 'startTimeUnixNano', 'endTimeUnixNano')
SPAN_INT = ('droppedAttributesCount', 'flags')
LOG_STR = ('timeUnixNano', 'observedTimeUnixNano', 'traceId', 'spanId', 'eventName', 'severityText')
LOG_INT = ('severityNumber', 'droppedAttributesCount', 'flags')
def typed(owner, strings, integers):
    return (all(isinstance(owner.get(f, ''), str) for f in strings)
            and all(isinstance(owner.get(f, 0), int) and not isinstance(owner.get(f, 0), bool)
                    for f in integers))
ok = all(typed(sp, SPAN_STR, SPAN_INT) for _, _, sp in spans)
ok = ok and all(typed(lr, LOG_STR, LOG_INT) for _, _, lr in records)
ok = ok and all(isinstance(sc.get(f, ''), str) for _, sc, _ in spans + records for f in ('name', 'version'))
ok = ok and all(isinstance(sp['status'].get(f, ''), str)
                for _, _, sp in spans if 'status' in sp for f in ('code', 'message'))
ok = ok and all(isinstance(ev.get(f, ''), str)
                for _, _, sp in spans for ev in sp.get('events', []) for f in ('timeUnixNano', 'name'))
print(ok)"

check "a numeric span name and scope name survive as strings" "99 5" "$PRELUDE
print(span_named('99')[0]['name'], [sc['name'] for _, sc, sp in spans if sp['name'] == 'typed'][0])"

# A record whose `resource` is not a map cannot carry the correlation key, so the run-id filter
# drops it. What matters is that the filter drops it rather than an exception taking the run down.
check "drops a record whose resource cannot carry the correlation key" "True" "$PRELUDE
print(not span_named('list-resource'))"

check "treats non-dict attributes as empty rather than dropping a real record" "[]" "$PRELUDE
print(span_named('string-attributes')[0]['attributes'])"

if grep -q "6 event(s) could not be used" <<<"$OUT"; then
  PASSED=$(( PASSED + 1 )); echo "  PASS  reports how many events it had to skip"
else
  FAILED=$(( FAILED + 1 )); echo "  FAIL  reports how many events it had to skip (got: $OUT)"
fi

# The counts in this line are the only external evidence of *where* each message went, and they are
# what makes the guards above falsifiable. Nine of the fifteen messages are JSON objects; without the
# non-object guard in read_vended_records all fifteen would be counted as records (the per-record
# backstop would then absorb the five `.get` failures, so the skipped count alone stays at 6 and
# hides the difference). Seven spans and one log record: the eighth object cannot carry a
# correlation key, so it is filtered rather than skipped.
if grep -qF "Rebuilt OTLP from 9 vended event(s): 7 span(s), 1 log record(s)" <<<"$OUT"; then
  PASSED=$(( PASSED + 1 )); echo "  PASS  counts objects as records and non-objects as skipped"
else
  FAILED=$(( FAILED + 1 )); echo "  FAIL  counts objects as records and non-objects as skipped (got: $OUT)"
fi

if grep -qE "hello|\bnot-a-map\b|cb7b84a7" <<<"$OUT"; then
  FAILED=$(( FAILED + 1 )); echo "  FAIL  never prints a skipped record's content (got: $OUT)"
else
  PASSED=$(( PASSED + 1 )); echo "  PASS  never prints a skipped record's content"
fi

echo "--- the per-record backstop ---"

# The `except Exception` around each record's conversion is the last line of defence for a vended
# shape none of the guards above anticipated, and it cannot be reached from the outside: every input
# that can be written by hand is caught by a specific guard first. Left uncovered, it is free to be
# narrowed (or deleted) with the suite still green — which is how a fatal parse path survived review
# once already. So reach it directly: load the transform as a module and make one conversion of one
# record raise. The healthy records around it must still be rebuilt, and the run must still exit 0.
export TRANSFORM FIXTURE
LOGS_OUT="$WORK_DIR/b-logs.jsonl"
TRACES_OUT="$WORK_DIR/b-traces.jsonl"

check "skips a record whose conversion raises, and keeps the rest" "0 True True" "
import contextlib, importlib.util, io, os, sys
sys.dont_write_bytecode = True  # do not leave a scripts/__pycache__ behind in the working tree
spec = importlib.util.spec_from_file_location('transform', os.environ['TRANSFORM'])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
real = module.to_scope
def exploding(record):
    if record.get('name') == 'AppStart':
        raise RuntimeError('a shape none of the guards anticipated')
    return real(record)
module.to_scope = exploding
captured = io.StringIO()
with contextlib.redirect_stdout(captured), contextlib.redirect_stderr(captured):
    status = module.main(['--run-id', 'run-a-1',
                         '--logs-out', os.environ['LOGS_OUT'],
                         '--traces-out', os.environ['TRACES_OUT'],
                         os.environ['FIXTURE']])
text = captured.getvalue()
print(status, '2 span(s), 2 log record(s)' in text, '1 event(s) could not be used' in text)"

# The write boundary is the same kind of unreachable second layer, for the same reason: `to_any_value`
# already converts a non-finite float to a string, so no input can now put one in front of
# `json.dumps`. What `allow_nan=False` buys is that if that guard is ever narrowed, the failure is a
# skipped record here rather than a bare `NaN` in the file — which Python re-reads happily and Swift
# rejects, printing the first 200 chars of the offending line, where the app monitor id sits. Reached
# directly, because there is no input that reaches it and an uncovered belt gets removed.
check "refuses to render a document Swift's JSONDecoder would reject" "None True" "
import importlib.util, os, sys
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('transform', os.environ['TRANSFORM'])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.serialize({'v': float('nan')}), module.serialize({'v': 1.5}) == '{\"v\": 1.5}')"

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
