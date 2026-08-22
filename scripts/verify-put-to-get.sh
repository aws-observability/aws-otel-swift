#!/bin/bash

# Put-to-get verification: fetch the telemetry this run exported to the *real* CloudWatch RUM data
# plane back out of the app monitor's vended CloudWatch Logs group, and rebuild the two OTLP/JSON
# files `Tests/ContractTests` already parses.
#
# The point is that the caller then runs `swift test --filter ContractTests` completely unmodified,
# so the very same assertions that guard the hermetic run also guard a real round trip. This script
# does not assert anything about the telemetry's *content* — that is the contract tests' job. It is
# responsible for exactly two things: getting all of this run's records, and shaping them.
#
# Deliberately shell + `aws logs filter-log-events` rather than a Swift test: the get side is a
# polling loop, and this keeps an AWS SDK dependency out of the `ContractTests` target.
#
# Polling to *quiescence*, not to first match. RUM delivers a run's telemetry to CloudWatch Logs in
# several batches over tens of seconds. The contract tests assert exact counts (3 HTTP spans, 4
# screen-appearance spans, 2 session-start log records...), so returning on the first matching event
# would hand them a partial set and produce a wall of count assertion failures that look like
# product bugs.
#
# Those same exact-count assertions are also the backstop for the opposite mistake. If this script
# rebuilt the two files as empty — or with the wrong run's records — the suite would not quietly
# pass; it would fail on counts. That is why this script deliberately does not assert anything about
# content: duplicating the counts here would create a second set of numbers to keep in step.
#
# Secret handling. The log group name is a CI secret (it embeds the app monitor id) and log contents
# are untrusted — the target app monitor has a public resource-based policy, so anyone with the id
# can write events into it. So:
#   * the log group name is never echoed, not even on failure. Failures name the correlation key and
#     the attempt count instead, and point at the secret that holds the group.
#   * fetched log events are never printed. Only counts.
#   * every channel that forwards text this script did not compose itself — the AWS CLI's stderr and
#     the rebuild step's stdout — is redacted before it is shown, structurally rather than by
#     substituting the one value this script happens to know. See redact_file().
#   * an option this script does not recognise is reported by *name*, never as the whole token:
#     `--log-group=<secret>` is one argument.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REGION="${AWS_OTEL_CONTRACT_REGION:-}"
LOG_GROUP="${AWS_OTEL_CONTRACT_LOG_GROUP:-}"
RUN_ID="${AWS_OTEL_CONTRACT_RUN_ID:-}"
START_TIME_MS=""

# Total polling budget. The caller's job is capped at 30 minutes (mirroring ContractTests.yml) and
# the put step consumes most of that, so this stays well clear of the cap.
TIMEOUT_SECONDS=600
# Fixed interval. Backoff is wrong here: quiescence is measured as "the count did not change
# between two polls", which only means something if the gap between polls is predictable.
POLL_INTERVAL_SECONDS=20
# How many consecutive polls must report an unchanged count before delivery is called complete.
STABLE_POLLS_REQUIRED=2

# The number of records a complete run vends, measured from a real end-to-end run (11 spans + 7 log
# records = 18). This is a *delivery-completeness floor*, not an assertion about the telemetry: it
# stops the loop from quiescing on an early partial batch. The authoritative per-signal counts live
# in Tests/ContractTests, which the caller runs next. Lower it (or raise it) if the demo app's
# instrumentation coverage changes; do not lower it to make a failing run pass.
MIN_RECORDS=18

# Where OTLPResolver looks. Hardcoded there relative to the directory holding Package.swift, which
# is why nothing about the contract tests needs to change for the real-endpoint path. Overridable
# only so this script's own tests can run without truncating a developer's local artifacts; CI never
# sets it, because the contract tests read the default path and nothing else.
OUT_DIR="${AWS_OTEL_CONTRACT_OUT_DIR:-$PROJECT_ROOT/Examples/AwsOtelUI/out}"
LOGS_OUT="$OUT_DIR/logs.jsonl"
TRACES_OUT="$OUT_DIR/traces.jsonl"

usage() {
  cat <<'USAGE'
Usage: verify-put-to-get.sh --run-id <key> --log-group <name> --region <region>
                            [--start-time-ms <epoch-ms>] [--timeout-seconds <n>]
                            [--min-records <n>]

Fetches this run's telemetry from the app monitor's vended CloudWatch Logs group and rebuilds
Examples/AwsOtelUI/out/{logs,traces}.jsonl in OTLP/JSON, ready for `swift test --filter
ContractTests`.

  --run-id           Correlation key stamped on the exported telemetry as the
                     aws.otel.contract.run.id resource attribute. Must match what
                     scripts/run-contract-tests.sh was given.
  --log-group        CloudWatch Logs group the app monitor delivers to. A secret; never echoed.
  --region           Region of the log group.
  --start-time-ms    Only consider events at or after this epoch-millisecond timestamp. Defaults
                     to 30 minutes ago. Pass the time the put step started to get a meaningful
                     put-to-queryable latency in the output.
  --timeout-seconds  Total polling budget. Default 600.
  --min-records      Delivery-completeness floor. Default 18.
  --poll-interval-seconds
                     Seconds between polls. Default 20. Quiescence is measured across polls, so
                     shortening this also shortens the window delivery must be quiet for.

Each flag also reads a matching environment variable: AWS_OTEL_CONTRACT_RUN_ID,
AWS_OTEL_CONTRACT_LOG_GROUP, AWS_OTEL_CONTRACT_REGION.

AWS_OTEL_CONTRACT_OUT_DIR overrides where the rebuilt files are written. It exists for this
script's own tests; the contract tests only read Examples/AwsOtelUI/out, so CI must not set it.
USAGE
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --log-group)
      LOG_GROUP="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --start-time-ms)
      START_TIME_MS="$2"
      shift 2
      ;;
    --timeout-seconds)
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    --min-records)
      MIN_RECORDS="$2"
      shift 2
      ;;
    --poll-interval-seconds)
      POLL_INTERVAL_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      # Print the option *name* only. The likeliest way to reach this branch is writing a real
      # invocation with `=` instead of a space — `--log-group=<the secret>` is a single token, so
      # echoing "$1" would put the whole log group into the output of a failed CI step, which is
      # precisely where nobody thinks to look for a leaked secret.
      echo "Unknown option: ${1%%=*}"
      usage
      exit 1
      ;;
  esac
done

# Validate inputs without echoing the secret ones.
if [[ -z "$RUN_ID" ]]; then
  echo "Error: --run-id is required"
  exit 1
fi
# Keep this in step with the identical check in scripts/run-contract-tests.sh. If the two
# disagree, the put side stamps a key the get side never searches for, and this script fails as a
# timeout with no explanation.
if [[ ! "$RUN_ID" =~ ^[A-Za-z0-9._:-]+$ ]]; then
  echo "Error: --run-id must match ^[A-Za-z0-9._:-]+\$ (got: $RUN_ID)"
  exit 1
fi
if [[ -z "$LOG_GROUP" ]]; then
  echo "Error: --log-group is required (set the CONTRACT_TEST_LOG_GROUP secret)"
  exit 1
fi
if [[ -z "$REGION" ]]; then
  echo "Error: --region is required (set the CONTRACT_TEST_REGION secret)"
  exit 1
fi
if [[ ! "$TIMEOUT_SECONDS" =~ ^[0-9]+$ || "$TIMEOUT_SECONDS" -lt 1 ]]; then
  echo "Error: --timeout-seconds must be a positive integer"
  exit 1
fi
if [[ ! "$MIN_RECORDS" =~ ^[0-9]+$ || "$MIN_RECORDS" -lt 1 ]]; then
  echo "Error: --min-records must be a positive integer"
  exit 1
fi
if [[ ! "$POLL_INTERVAL_SECONDS" =~ ^[0-9]+$ || "$POLL_INTERVAL_SECONDS" -lt 1 ]]; then
  echo "Error: --poll-interval-seconds must be a positive integer"
  exit 1
fi
if [[ -z "$START_TIME_MS" ]]; then
  START_TIME_MS=$(( ($(date +%s) - 1800) * 1000 ))
fi
if [[ ! "$START_TIME_MS" =~ ^[0-9]+$ ]]; then
  echo "Error: --start-time-ms must be an epoch-millisecond integer"
  exit 1
fi

# Server-side prefilter. CloudWatch Logs filter patterns tokenize the message, and the exact
# tokenization of punctuation is not something to bet a CI job on: a pattern of "12345-6" may or
# may not match `"aws.otel.contract.run.id":"12345-6"`. So filter on the longest purely
# alphanumeric run inside the key — which for the `<run_id>-<run_attempt>` form the workflow uses
# is the GitHub run id, already unique on its own — and then match the *full* key exactly, locally,
# against the resource attribute. The prefilter can only ever be too loose, never too strict.
PREFILTER_TERM=$(printf '%s' "$RUN_ID" | tr -c '[:alnum:]' '\n' | awk '
  { if (length($0) > length(longest)) longest = $0 }
  END { print longest }
')
if [[ "${#PREFILTER_TERM}" -lt 6 ]]; then
  # Too short to narrow anything usefully; a common substring would match half the group.
  PREFILTER_TERM="$RUN_ID"
fi

echo "Fetching telemetry for correlation key: aws.otel.contract.run.id=$RUN_ID"
echo "  region:            $REGION"
echo "  log group:         (withheld — the CONTRACT_TEST_LOG_GROUP secret)"
echo "  events at/after:   $START_TIME_MS (epoch ms)"
echo "  polling budget:    ${TIMEOUT_SECONDS}s, every ${POLL_INTERVAL_SECONDS}s"
echo "  complete when:     >= $MIN_RECORDS records and the count is unchanged over" \
  "$STABLE_POLLS_REQUIRED consecutive polls"
echo "  server prefilter:  \"$PREFILTER_TERM\" (exact match on the full key is done locally)"
echo "  rebuilding:        Examples/AwsOtelUI/out/{logs,traces}.jsonl"

WORK_DIR=$(mktemp -d)
STDERR_FILE="$WORK_DIR/aws-stderr.txt"
FETCHED_FILE="$WORK_DIR/fetched.json"
trap 'rm -rf "$WORK_DIR"' EXIT

# Prints the AWS CLI's stderr with the sensitive parts removed, keeping the rest — losing the whole
# message would make a real failure undiagnosable.
#
# Substituting the log group name is not sufficient, and the AccessDenied path is where that shows.
# The CLI answers a denial by quoting the caller's own identity back:
#
#   User: arn:aws:sts::<account>:assumed-role/<role>/<session> is not authorized to perform:
#   logs:FilterLogEvents on resource: arn:aws:logs:<region>:<account>:log-group:<group>:*
#
# so the account id appears twice and the IAM role name once. Neither is passed to this script, so
# neither can be matched against a known value — and GitHub's own masking does not cover them
# either: the registered secret is the whole role ARN, and masking is substring-exact, so a bare
# account id embedded in a *different* ARN prints in the clear. Redaction therefore has to be
# structural: any 12-digit run is an account id, and anything after `assumed-role/`, `role/` or
# `user/` is a principal name. Both are matched by shape, not by value, which is what makes this
# work on text this script has never seen.
#
# Takes a path so it can be pointed at anything this script did not compose itself. Two channels
# qualify: the AWS CLI's stderr, and the rebuild step's own stdout. The rebuild step is never handed
# the log group and a Python traceback carries no data values, so no leak has been *demonstrated*
# through the second one — routing it through here is defence in depth against a future change that
# starts echoing its input, not a fix for a known leak.
redact_file() {
  LOG_GROUP="$LOG_GROUP" python3 - "$1" <<'PYREDACT'
import os
import re
import sys

with open(sys.argv[1], encoding="utf-8", errors="replace") as handle:
    text = handle.read()

group = os.environ.get("LOG_GROUP", "")
if group:
    text = text.replace(group, "<CONTRACT_TEST_LOG_GROUP>")

# Order matters: redact principals before account ids, so the ARN is still recognisable as an ARN
# in the output rather than a row of placeholders.
text = re.sub(r"\b(assumed-role|federated-user|role|user)/[^\s\"'),]+", r"\1/<PRINCIPAL>", text)
text = re.sub(r"(?<![\d.])\d{12}(?![\d.])", "<ACCOUNT_ID>", text)

if text and not text.endswith("\n"):
    text += "\n"
sys.stdout.write(text)
PYREDACT
}

# The two call-site wrappers. Both swallow a redaction failure into a placeholder line rather than
# letting it propagate: this script runs under `set -e`, and on the poll path a non-zero status here
# would abort the whole run with the shell's exit code in place of the diagnosis it was printing.
# Losing one error message is a far smaller failure than losing the run.
redacted_stderr() {
  redact_file "$STDERR_FILE" || echo "(AWS CLI error withheld — redaction unavailable)"
}

redacted_transform_output() {
  redact_file "$WORK_DIR/transform.txt" || echo "(rebuild step output withheld — redaction unavailable)"
}

# Create the output directory and truncate any previous contents *before* polling. In put-to-get
# mode AwsOtelUI never runs, so nothing else writes here — but a stale pair of files from an earlier
# run would let the contract tests assert against the wrong run's telemetry and report a false green.
mkdir -p "$OUT_DIR"
: > "$LOGS_OUT"
: > "$TRACES_OUT"

POLL_STARTED_AT=$(date +%s)
DEADLINE=$(( POLL_STARTED_AT + TIMEOUT_SECONDS ))
ATTEMPT=0
LAST_COUNT=-1
STABLE_POLLS=0
RECORD_COUNT=0
# Counted so the timeout message can tell "nothing was ever delivered" apart from "every fetch was
# throttled". Both end with zero records, and only one of them is a payload problem.
TRANSIENT_FAILURES=0

while true; do
  ATTEMPT=$(( ATTEMPT + 1 ))

  # `events[*].message` rather than `--output text`: text output is tab-delimited and a vended
  # message may itself contain newlines, so its rows cannot be split back apart reliably. The
  # response is written to a temp file and never printed — it contains the app monitor id (a
  # secret) and, because the monitor has a public write path, arbitrary third-party content.
  #
  # One query covers both delivery streams (`.../otel-spans` and `.../otel-events`); the transform
  # tells spans and log records apart per record. No `--limit`: the start-time window plus the
  # prefilter make the result set this run's own records, so letting the CLI paginate to the end is
  # both cheap and the only way to be sure nothing was truncated.
  set +e
  aws logs filter-log-events \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP" \
    --start-time "$START_TIME_MS" \
    --filter-pattern "\"$PREFILTER_TERM\"" \
    --query 'events[*].message' \
    --output json \
    > "$FETCHED_FILE" 2>"$STDERR_FILE"
  AWS_EXIT=$?
  set -e

  if [[ $AWS_EXIT -ne 0 ]]; then
    ERROR_TEXT=$(cat "$STDERR_FILE")
    case "$ERROR_TEXT" in
      *AccessDenied*|*not\ authorized*|*UnrecognizedClientException*|*InvalidClientTokenId*|*ExpiredToken*)
        echo "FAIL: the assumed role cannot read the log group. This is a permissions problem, not"
        echo "      an ingestion problem — retrying will not help."
        echo "      The role needs logs:FilterLogEvents on the log-group ARN *with* a trailing"
        echo "      \":*\" (FilterLogEvents authorizes against a stream-qualified ARN)."
        echo "AWS CLI error (log group redacted):"
        redacted_stderr
        exit 1
        ;;
      *ResourceNotFoundException*)
        echo "FAIL: the log group does not exist in $REGION. Check the CONTRACT_TEST_LOG_GROUP and"
        echo "      CONTRACT_TEST_REGION secrets — retrying will not help."
        echo "AWS CLI error (log group redacted):"
        redacted_stderr
        exit 1
        ;;
      *)
        TRANSIENT_FAILURES=$(( TRANSIENT_FAILURES + 1 ))
        echo "Attempt $ATTEMPT: filter-log-events failed transiently; will retry."
        echo "AWS CLI error (log group redacted):"
        redacted_stderr
        echo '[]' > "$FETCHED_FILE"
        ;;
    esac
  fi

  # Rebuild straight into the final paths. The transform truncates and applies the exact-key filter,
  # so the line counts below are the authoritative count of *this run's* records — no separate
  # counting logic that could drift from the filter that actually decides what the tests see. Its
  # exit 1 ("nothing matched yet") is expected while polling.
  set +e
  "$SCRIPT_DIR/vended-logs-to-otlp.py" \
    --run-id "$RUN_ID" \
    --logs-out "$LOGS_OUT" \
    --traces-out "$TRACES_OUT" \
    "$FETCHED_FILE" > "$WORK_DIR/transform.txt" 2>&1
  TRANSFORM_EXIT=$?
  set -e

  # Exit 1 is "nothing matched yet" and is expected while polling. Anything else means the transform
  # itself broke, which is a tooling bug: polling through it would burn the whole budget and then
  # report a delivery failure for a Python error. Fail immediately and say which side broke.
  if (( TRANSFORM_EXIT != 0 && TRANSFORM_EXIT != 1 )); then
    echo "FAIL: the rebuild step failed (scripts/vended-logs-to-otlp.py exited $TRANSFORM_EXIT)."
    echo "      This is a bug in the rebuild step or an input shape it cannot handle — not a"
    echo "      delivery problem, and not something retrying will fix."
    redacted_transform_output
    exit 1
  fi

  # `grep -c ''` prints 0 *and* exits 1 on an empty file, so the `|| true` is load-bearing. The
  # numeric guard is what stops a future change from feeding an empty string into $(( )), which bash
  # silently reads as 0 — turning "the counter broke" into "nothing arrived yet".
  SPAN_COUNT=$(grep -c '' < "$TRACES_OUT" || true)
  LOG_COUNT=$(grep -c '' < "$LOGS_OUT" || true)
  if [[ ! "$SPAN_COUNT" =~ ^[0-9]+$ || ! "$LOG_COUNT" =~ ^[0-9]+$ ]]; then
    echo "FAIL: could not count the rebuilt records (got spans='$SPAN_COUNT' logs='$LOG_COUNT')."
    echo "      This is a bug in this script, not a delivery problem."
    exit 1
  fi
  RECORD_COUNT=$(( SPAN_COUNT + LOG_COUNT ))

  # STABLE_POLLS counts *comparisons against a previous count*, so it is 0 on the first poll: a
  # single poll cannot distinguish a complete delivery from the first of several batches. Starting it
  # at 1 on a change would make STABLE_POLLS_REQUIRED=2 mean one quiet interval rather than two — and
  # a real run has been observed holding a count for one interval and then growing anyway.
  if (( RECORD_COUNT == LAST_COUNT )); then
    STABLE_POLLS=$(( STABLE_POLLS + 1 ))
  else
    STABLE_POLLS=0
  fi
  LAST_COUNT=$RECORD_COUNT

  if (( RECORD_COUNT >= MIN_RECORDS && STABLE_POLLS >= STABLE_POLLS_REQUIRED )); then
    break
  fi

  NOW=$(date +%s)
  if (( NOW + POLL_INTERVAL_SECONDS > DEADLINE )); then
    ELAPSED=$(( NOW - POLL_STARTED_AT ))
    cat <<EOF
FAIL: this run's telemetry did not fully arrive in CloudWatch Logs within the budget.

  searched for:     aws.otel.contract.run.id=$RUN_ID
                    (server-side prefilter "$PREFILTER_TERM", then an exact match on the
                    aws.otel.contract.run.id resource attribute)
  log group:        withheld — it is the CONTRACT_TEST_LOG_GROUP secret of the \`put-to-get\`
                    GitHub environment. Read that secret's value to query the group by hand.
  region:           $REGION
  events at/after:  $START_TIME_MS (epoch ms)
  records found:    $RECORD_COUNT ($SPAN_COUNT span(s), $LOG_COUNT log record(s)); needed >= $MIN_RECORDS
  attempts:         $ATTEMPT over ${ELAPSED}s (budget ${TIMEOUT_SECONDS}s)
  transient fetch failures: $TRANSIENT_FAILURES of $ATTEMPT attempt(s)

This is not a bare timeout. Credentials and the log group are fine — no AccessDenied and no
ResourceNotFound — so the query ran; the records were simply not all visible in the group before the
budget ran out. Note that a query returning nothing is not proof that nothing was delivered: if the
transient-failure count above is close to the attempt count, treat this as a throttled fetch rather
than a payload problem. Likely causes, in order:
EOF
    if (( RECORD_COUNT == 0 )); then
      cat <<EOF
  1. Nothing at all arrived. The put step exported but the data plane rejected the payload — spans
     are validated per record, so an export can return 2xx with everything rejected. Check the put
     step's output for partial_success / rejected_log_records / rejected_spans.
  2. The aws.otel.contract.run.id resource attribute did not survive into the payload, so the key
     is not in the events at all. Reproduce hermetically: run the harness with
     --endpoint http://localhost:3000 --run-id \$KEY and grep Examples/AwsOtelUI/out for the key.
  3. The put and get sides disagree on the key. Compare this value with the "Correlation key:"
     line printed by scripts/run-contract-tests.sh.
  4. Ingestion is slower than the ${TIMEOUT_SECONDS}s budget. Re-run and compare before treating
     this as a payload bug.
EOF
    else
      cat <<EOF
  1. Delivery is partial: $RECORD_COUNT of the expected $MIN_RECORDS records arrived and the rest never
     did. Some were accepted, so the endpoint, credentials and correlation key are all fine — this
     is either per-record rejection or slow delivery. Check the put step's output for
     partial_success / rejected_log_records / rejected_spans.
  2. Ingestion is slower than the ${TIMEOUT_SECONDS}s budget. Re-run and compare; if a longer budget
     passes, raise --timeout-seconds rather than treating this as a payload bug.
  3. The demo app genuinely emitted fewer records than --min-records expects (instrumentation
     coverage changed, or a UI interaction did not fire on this simulator). Confirm against a
     hermetic run, then adjust --min-records — do not lower it just to get past this check.
EOF
    fi
    # The transform's own summary, on this path too — it is the only place the skipped-event count is
    # reported, and a run where most events were unusable looks identical to a slow one from here.
    # The success path prints it below; the WORK_DIR trap would otherwise delete it unread.
    if [[ -s "$WORK_DIR/transform.txt" ]]; then
      echo
      echo "Last rebuild attempt reported:"
      while IFS= read -r LINE; do
        echo "  $LINE"
      done < "$WORK_DIR/transform.txt"
    fi
    exit 1
  fi

  echo "Attempt $ATTEMPT: $RECORD_COUNT record(s) so far ($SPAN_COUNT span(s), $LOG_COUNT log record(s))," \
    "unchanged over $STABLE_POLLS poll(s); sleeping ${POLL_INTERVAL_SECONDS}s" \
    "($(( DEADLINE - NOW ))s of budget left)."
  sleep "$POLL_INTERVAL_SECONDS"
done

NOW=$(date +%s)
echo "PASS: delivery is complete — $RECORD_COUNT record(s) ($SPAN_COUNT span(s), $LOG_COUNT log record(s))" \
  "after $ATTEMPT attempt(s), $(( NOW - POLL_STARTED_AT ))s of polling."
echo "      put -> fully queryable: at most $(( NOW - (START_TIME_MS / 1000) ))s" \
  "(from --start-time-ms; an upper bound, since polling is discrete and the start time is backdated)"

# Report the transform's own summary, and confirm the two files really are parseable OTLP rather
# than trusting the line count. A malformed rebuild would otherwise reach the contract tests as
# empty arrays: OtlpFileParser swallows log decode failures and only *prints* trace decode
# failures, so the suite would fail on counts and look like the telemetry never arrived.
redacted_transform_output
python3 - "$LOGS_OUT" "$TRACES_OUT" <<'PYCHECK'
import json
import sys


def reject(name):
    """Make json.loads strict about the tokens Python invented.

    Python accepts bare `NaN`, `Infinity` and `-Infinity` and round-trips them happily; Swift's
    JSONDecoder rejects all three. Without this, an OTLP file holding one would sail through this
    gate and fail over in Swift instead — and a trace decode failure there *prints the first 200
    chars of the line*, which is where the app monitor id sits once the resource attributes are
    sorted. So a lenient check here turns a lost record into a leaked secret.
    """
    raise ValueError("bare %s is not valid JSON" % name)


# `exception.stacktrace` is the only attribute an assertion reads positionally rather than by
# equality: HangTests looks for a `Thread N Crashed:` header that sits on a non-zero thread, well
# into the report. It is also the only one long enough to be cut — LiveStackTraceReporter applies
# `prefix(10_000)`, a fixed character count over content whose length varies with thread count and
# frame widths. So whether that header lands inside the cut is luck, and when it falls outside, the
# `Thread 0:` header near the start still passes: exactly the shape of a flake.
#
# Measured here because this is where the rebuilt files are already open. The offsets are the point:
# a marker at 9,900 of 10,000 chars is one thread away from vanishing, which a bare present/absent
# list would report as fine. Lengths, offsets, marker names and header counts only — the value is
# third-party-writable content and is never printed.
STACKTRACE_KEY = "exception.stacktrace"
MARKERS = ("Thread 0:", "Crashed:", "libsystem_kernel.dylib")
stacktraces = []

for path, root, group, leaf in (
    (sys.argv[1], "resourceLogs", "scopeLogs", "logRecords"),
    (sys.argv[2], "resourceSpans", "scopeSpans", "spans"),
):
    with open(path, encoding="utf-8") as handle:
        lines = [line for line in handle if line.strip()]
    total = 0
    for number, line in enumerate(lines, start=1):
        try:
            document = json.loads(line, parse_constant=reject)
        except ValueError as error:
            # ValueError, not json.JSONDecodeError: it is the parent class, so it covers both a
            # malformed line and the strictness above. Report the position only — the line itself
            # holds the app monitor id.
            sys.exit("FAIL: %s line %d is not valid JSON (%s)" % (path, number, error))
        for resource in document[root]:
            for scope in resource[group]:
                total += len(scope[leaf])
                for item in scope[leaf]:
                    for attribute in item.get("attributes") or []:
                        if attribute.get("key") != STACKTRACE_KEY:
                            continue
                        text = (attribute.get("value") or {}).get("stringValue")
                        if isinstance(text, str):
                            stacktraces.append(text)
    print("      %s: %d line(s), %d %s" % (path, len(lines), total, leaf))

# Longest first: if a cap is in play, the longest value is the one sitting on it, and a run where
# every value lands on the same round number is a cap rather than a coincidence.
for rank, text in enumerate(sorted(stacktraces, key=len, reverse=True), start=1):
    # `marker@offset` against the char count is the headroom. Read `Crashed:@9900` of 10000 as a
    # pass that was one longer thread away from failing.
    present = [
        "%s@%d" % (marker, text.index(marker)) for marker in MARKERS if marker in text
    ] or ["none"]
    print(
        "      %s #%d: %d chars, %d thread header(s), ends mid-line: %s, markers: %s"
        % (
            STACKTRACE_KEY,
            rank,
            len(text),
            text.count("\nThread "),
            "no" if text.endswith("\n") else "yes",
            ", ".join(present),
        )
    )
PYCHECK

echo
echo "Rebuilt OTLP is in place. The caller runs \`swift test --filter ContractTests\` next: the same"
echo "assertions as the hermetic run, now reading this run's telemetry as CloudWatch vended it."
