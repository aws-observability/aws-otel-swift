#!/usr/bin/env python3

"""Turn a CloudWatch RUM app monitor's vended log events back into OTLP/JSON.

This is the "get" side of the put-to-get contract test. The point is that
``Tests/ContractTests`` runs *unmodified* against a real round trip: the demo app exports to the
real RUM data plane, RUM delivers the telemetry to a CloudWatch Logs group, and this script
rebuilds the two files those tests already parse --
``Examples/AwsOtelUI/out/logs.jsonl`` and ``traces.jsonl``, one JSON document per line. No test
source, resolver path or assertion changes.

What a vended event actually looks like (established empirically against a live app monitor, not
from the OTLP spec -- the two differ in every way that matters here). One event per span or log
record, flattened, with the RUM envelope on top::

    {
      "resourceArn": "arn:aws:rum:...:appmonitor/NAME",
      "awsRUMAppMonitorId": "...",
      "resource": {"attributes": {"service.name": "SimpleAwsDemo", ...}},
      "scope": {"name": "software.amazon.opentelemetry.appstart", "version": ""},
      "traceId": "cb7b...", "spanId": "31d6...", "parentSpanId": "",
      "name": "AppStart", "kind": "INTERNAL",
      "startTimeUnixNano": 1787340061523443968, "endTimeUnixNano": 1787340064949510144,
      "attributes": {"start.type": "cold", "active_prewarm": false,
                     "process.memory.usage": 355.719, "http.status_code": 200},
      "status": {"code": "UNSET"}, "durationNano": 3426066176, ...
    }

So the differences this script has to bridge are: attribute *maps* rather than OTLP keyed arrays;
timestamps as JSON numbers rather than strings; ``kind``/``status.code`` as bare enum names rather
than ``SPAN_KIND_*``/``STATUS_CODE_*``; and natively-typed attribute values rather than OTLP
``AnyValue`` wrappers. Resource attributes, scope names, span identity, status messages and
attribute types all survive the round trip intact, which is what makes running the real
assertions possible at all.

Filtering. The target app monitor has a public resource-based policy, so anything holding its id
can write to it and the log group is a shared, untrusted write target. Records are therefore kept
only when their ``aws.otel.contract.run.id`` resource attribute equals ``--run-id``. Matching no
records is an error, not an empty success: ``OtlpFileParser`` swallows log decode failures and
merely prints trace decode failures, so two empty files would surface as a wall of assertion
failures that read like "the telemetry never arrived".

Secret handling. Vended events embed the app monitor id and arbitrary third-party content, so
nothing from a record is ever printed -- only counts, and the correlation key (a GitHub run id).
"""

import argparse
import json
import sys

RUN_ID_ATTRIBUTE = "aws.otel.contract.run.id"


def to_any_value(value):
    """Wrap a natively-typed vended attribute value in an OTLP ``AnyValue``.

    The int/float split is load-bearing. ``Tests/ContractTests`` reads
    ``http.status_code`` through ``value.intValue`` (declared ``String?``, because OTLP/JSON
    encodes 64-bit ints as strings) and ``process.memory.usage`` through ``value.doubleValue``.
    Python's JSON parser preserves the distinction from the wire text -- RUM vends a zero CPU
    reading as ``0.0``, which parses to a float, so it stays a double rather than collapsing into
    an integer and making SystemMetricsTests' lookup return nil on every record.
    """
    # bool before int: bool is a subclass of int in Python.
    if isinstance(value, bool):
        return {"boolValue": value}
    if isinstance(value, int):
        return {"intValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    # Arrays and maps are not produced by this SDK and no assertion reads one. Round-tripping the
    # JSON keeps the value legible in the output rather than dropping the attribute silently.
    return {"stringValue": json.dumps(value, sort_keys=True)}


def to_attribute_list(attributes):
    """Convert a vended attribute map into an OTLP keyed array, ordered for readable diffs."""
    return [
        {"key": key, "value": to_any_value(value)}
        for key, value in sorted((attributes or {}).items())
    ]


def to_resource(record):
    return {"attributes": to_attribute_list(record.get("resource", {}).get("attributes"))}


def to_scope(record):
    scope = record.get("scope") or {}
    # `name` is what every contract test filters on; the parser requires it to be present.
    return {"name": scope.get("name", ""), "version": scope.get("version", "")}


def nanos(value):
    """Timestamps arrive as JSON numbers; the parser's fields are non-optional `String`.

    Python parses these 19-digit integers exactly (arbitrary precision), so stringifying them here
    preserves the nanosecond value rather than rounding it through a float, which HangTests' 4--6
    second duration window would otherwise be at the mercy of.
    """
    if value is None:
        return "0"
    return str(value)


def to_status(status):
    """``{"code": "ERROR", "message": "404"}`` -> ``{"code": "STATUS_CODE_ERROR", ...}``.

    An absent ``message`` must stay absent: NetworkTests asserts
    ``XCTAssertNil(span200?.status?.message)`` on the 2xx span, and synthesizing an empty string
    would turn that into a failure.
    """
    if status is None:
        return None
    converted = {}
    code = status.get("code")
    if code is not None:
        converted["code"] = code if code.startswith("STATUS_CODE_") else "STATUS_CODE_" + code
    if status.get("message") is not None:
        converted["message"] = status["message"]
    return converted


def to_span_event(event):
    return {
        "timeUnixNano": nanos(event.get("timeUnixNano")),
        "name": event.get("name", ""),
        "attributes": to_attribute_list(event.get("attributes")),
    }


def is_span(record):
    """Spans and log records are vended to different streams, but detect per record.

    Reading both streams through one code path keeps the caller from having to pair a stream name
    with a record kind -- and a misrouted record would be far more confusing than an unmatched one.
    """
    return "startTimeUnixNano" in record and "name" in record


def to_span(record):
    span = {
        "traceId": record.get("traceId", ""),
        "spanId": record.get("spanId", ""),
        "parentSpanId": record.get("parentSpanId", ""),
        "name": record.get("name", ""),
        # Vended as the bare enum name ("INTERNAL"); OTLP/JSON spells it out.
        "kind": "SPAN_KIND_" + record.get("kind", "UNSPECIFIED"),
        "startTimeUnixNano": nanos(record.get("startTimeUnixNano")),
        "endTimeUnixNano": nanos(record.get("endTimeUnixNano")),
        "attributes": to_attribute_list(record.get("attributes")),
        "droppedAttributesCount": record.get("droppedAttributesCount", 0),
        "flags": record.get("flags", 0),
        "events": [to_span_event(event) for event in record.get("events", [])],
    }
    status = to_status(record.get("status"))
    if status is not None:
        span["status"] = status
    return span


def to_log_record(record):
    return {
        "timeUnixNano": nanos(record.get("timeUnixNano")),
        "observedTimeUnixNano": nanos(record.get("observedTimeUnixNano")),
        "severityNumber": record.get("severityNumber", 0),
        "severityText": record.get("severityText", ""),
        "attributes": to_attribute_list(record.get("attributes")),
        "traceId": record.get("traceId", ""),
        "spanId": record.get("spanId", ""),
        # The SDK sets the top-level OTLP eventName, and the data plane requires a non-empty one.
        # Every contract test that looks at a log record matches on it.
        "eventName": record.get("eventName", ""),
        "droppedAttributesCount": record.get("droppedAttributesCount", 0),
        "flags": record.get("flags", 0),
    }


def run_id_of(record):
    return (record.get("resource", {}).get("attributes") or {}).get(RUN_ID_ATTRIBUTE)


def messages_in(document):
    """Pull the log-event message strings out of whichever shape the caller fetched.

    Two shapes are accepted. A full ``aws logs filter-log-events`` document, and the bare array of
    strings that ``--query 'events[*].message' --output json`` projects. The fetch step uses the
    latter -- ``--output text`` is tab-delimited and vended messages can contain newlines, so its
    rows cannot be split back apart reliably -- but accepting the raw document too keeps a hand-run
    ``filter-log-events`` usable as input when debugging a failed CI run.
    """
    if isinstance(document, dict):
        return [event.get("message") for event in document.get("events", [])]
    if isinstance(document, list):
        return [item.get("message") if isinstance(item, dict) else item for item in document]
    raise ValueError(
        "expected a filter-log-events document or an array of log-event messages, got %s"
        % type(document).__name__
    )


def read_vended_records(paths):
    """Read the fetched log events and parse each message into a vended record.

    Accepts several inputs so the caller can pass one file per log stream (spans and log records
    are delivered to different streams) or per page. A message that is not JSON is skipped rather
    than fatal: the app monitor is a public write target, so unparseable content is somebody
    else's problem, not a reason to fail this run.
    """
    records = []
    skipped = 0
    for path in paths:
        if path == "-":
            document = json.load(sys.stdin)
        else:
            with open(path, encoding="utf-8") as handle:
                document = json.load(handle)
        for message in messages_in(document):
            if not message:
                continue
            try:
                records.append(json.loads(message))
            except json.JSONDecodeError:
                skipped += 1
    return records, skipped


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Rebuild OTLP/JSON JSONL from a RUM app monitor's vended CloudWatch Logs.",
    )
    parser.add_argument(
        "--run-id",
        required=True,
        help="Correlation key. Only records whose %s resource attribute equals this are kept."
        % RUN_ID_ATTRIBUTE,
    )
    parser.add_argument("--logs-out", required=True, help="Path to write logs.jsonl.")
    parser.add_argument("--traces-out", required=True, help="Path to write traces.jsonl.")
    parser.add_argument(
        "inputs",
        nargs="*",
        default=["-"],
        help="`aws logs filter-log-events` JSON documents. Reads stdin when omitted.",
    )
    args = parser.parse_args(argv)

    records, skipped = read_vended_records(args.inputs or ["-"])

    span_lines = []
    log_lines = []
    for record in records:
        if run_id_of(record) != args.run_id:
            continue
        resource = to_resource(record)
        scope = to_scope(record)
        if is_span(record):
            span_lines.append(
                {
                    "resourceSpans": [
                        {
                            "resource": resource,
                            "scopeSpans": [{"scope": scope, "spans": [to_span(record)]}],
                        }
                    ]
                }
            )
        else:
            log_lines.append(
                {
                    "resourceLogs": [
                        {
                            "resource": resource,
                            "scopeLogs": [{"scope": scope, "logRecords": [to_log_record(record)]}],
                        }
                    ]
                }
            )

    # Truncate unconditionally, before deciding whether there is anything to report. A previous
    # run's files left in place would let the contract tests pass against the wrong telemetry.
    for path, lines in ((args.logs_out, log_lines), (args.traces_out, span_lines)):
        with open(path, "w", encoding="utf-8") as handle:
            for line in lines:
                handle.write(json.dumps(line) + "\n")

    print(
        "Rebuilt OTLP from %d vended event(s): %d span(s), %d log record(s) for %s=%s."
        % (len(records), len(span_lines), len(log_lines), RUN_ID_ATTRIBUTE, args.run_id)
    )
    if skipped:
        print("  (%d event(s) were not JSON and were skipped)" % skipped)

    if not span_lines and not log_lines:
        print(
            "ERROR: none of the %d vended event(s) carried %s=%s, so %s and %s are empty.\n"
            "       Not treating this as success: OtlpFileParser swallows log decode failures and\n"
            "       only prints trace decode failures, so empty inputs would surface as a wall of\n"
            "       contract-test assertion failures that read like the telemetry never arrived."
            % (
                len(records),
                RUN_ID_ATTRIBUTE,
                args.run_id,
                args.logs_out,
                args.traces_out,
            ),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
