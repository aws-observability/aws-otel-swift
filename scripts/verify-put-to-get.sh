#!/bin/bash

# Put-to-get verification: prove that telemetry exported by the contract test harness was actually
# accepted by the CloudWatch RUM data plane, by finding this run's correlation key in the app
# monitor's vended CloudWatch Logs group.
#
# Deliberately shell + `aws logs filter-log-events` rather than a Swift test: the get side is a
# polling loop, and this keeps an AWS SDK dependency out of the `ContractTests` target.
#
# Secret handling. The log group name is a CI secret (it embeds the app monitor id) and log
# contents are untrusted — the target app monitor has a public resource-based policy, so anyone
# with the id can write events into it. So:
#   * the log group name is never echoed, not even on failure. Failures name the correlation key
#     and the attempt count instead, and point at the secret that holds the group.
#   * matched log events are never printed. Only counts, timestamps and the key are.
#   * AWS CLI stderr is redacted before it is shown.

set -euo pipefail

REGION="${AWS_OTEL_CONTRACT_REGION:-}"
LOG_GROUP="${AWS_OTEL_CONTRACT_LOG_GROUP:-}"
RUN_ID="${AWS_OTEL_CONTRACT_RUN_ID:-}"
START_TIME_MS=""

# Total polling budget. The caller's job is capped at 30 minutes (mirroring ContractTests.yml) and
# the put step consumes most of that, so this stays well clear of the cap.
TIMEOUT_SECONDS=420
# Backoff: first check is immediate (cheap, and occasionally the event is already there), then
# 10s doubling to a 30s ceiling. Roughly 20 attempts inside the default budget.
INITIAL_DELAY_SECONDS=10
MAX_DELAY_SECONDS=30

usage() {
  cat <<'USAGE'
Usage: verify-put-to-get.sh --run-id <key> --log-group <name> --region <region>
                            [--start-time-ms <epoch-ms>] [--timeout-seconds <n>]

  --run-id           Correlation key stamped on the exported telemetry as the
                     aws.otel.contract.run.id resource attribute. Must match what
                     scripts/run-contract-tests.sh was given.
  --log-group        CloudWatch Logs group the app monitor delivers to. A secret; never echoed.
  --region           Region of the log group.
  --start-time-ms    Only consider events at or after this epoch-millisecond timestamp. Defaults
                     to 30 minutes ago. Pass the time the put step started to get a meaningful
                     put-to-queryable latency in the output.
  --timeout-seconds  Total polling budget. Default 420.

Each flag also reads a matching environment variable: AWS_OTEL_CONTRACT_RUN_ID,
AWS_OTEL_CONTRACT_LOG_GROUP, AWS_OTEL_CONTRACT_REGION.
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option $1"
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
# is the GitHub run id, already unique on its own — and then confirm the *full* key locally with
# an exact substring match. The prefilter can only ever be too loose, never too strict.
PREFILTER_TERM=$(printf '%s' "$RUN_ID" | tr -c '[:alnum:]' '\n' | awk '
  { if (length($0) > length(longest)) longest = $0 }
  END { print longest }
')
if [[ "${#PREFILTER_TERM}" -lt 6 ]]; then
  # Too short to narrow anything usefully; a common substring would match half the group.
  PREFILTER_TERM="$RUN_ID"
fi

echo "Verifying ingestion of correlation key: aws.otel.contract.run.id=$RUN_ID"
echo "  region:            $REGION"
echo "  log group:         (withheld — the CONTRACT_TEST_LOG_GROUP secret)"
echo "  events at/after:   $START_TIME_MS (epoch ms)"
echo "  polling budget:    ${TIMEOUT_SECONDS}s"
echo "  server prefilter:  \"$PREFILTER_TERM\" (exact match on the full key is done locally)"

STDERR_FILE=$(mktemp)
trap 'rm -f "$STDERR_FILE"' EXIT

# Prints the AWS CLI's stderr with the log group name removed. Nothing else in that stream is
# secret, and losing the rest of the message would make a real failure undiagnosable.
redacted_stderr() {
  local message
  message=$(cat "$STDERR_FILE")
  printf '%s\n' "${message//"$LOG_GROUP"/<CONTRACT_TEST_LOG_GROUP>}"
}

POLL_STARTED_AT=$(date +%s)
DEADLINE=$(( POLL_STARTED_AT + TIMEOUT_SECONDS ))
DELAY=$INITIAL_DELAY_SECONDS
ATTEMPT=0

while true; do
  ATTEMPT=$(( ATTEMPT + 1 ))

  # `--output text` gives one `timestamp<TAB>message` row per event. The response is captured into
  # a variable and never printed: it may contain the app monitor id (a secret) and, because the
  # monitor has a public write path, arbitrary third-party content.
  set +e
  EVENTS=$(aws logs filter-log-events \
    --region "$REGION" \
    --log-group-name "$LOG_GROUP" \
    --start-time "$START_TIME_MS" \
    --filter-pattern "\"$PREFILTER_TERM\"" \
    --limit 500 \
    --query 'events[*].[timestamp,message]' \
    --output text 2>"$STDERR_FILE")
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
        echo "Attempt $ATTEMPT: filter-log-events failed transiently; will retry."
        echo "AWS CLI error (log group redacted):"
        redacted_stderr
        EVENTS=""
        ;;
    esac
  fi

  # Exact substring match on the full key. `grep -F` so nothing in the key is treated as a
  # pattern, and `-m1` so at most one row is held.
  MATCH_ROW=$(printf '%s\n' "$EVENTS" | grep -F -m1 -e "$RUN_ID" || true)
  if [[ -n "$MATCH_ROW" ]]; then
    NOW=$(date +%s)
    MATCH_COUNT=$(printf '%s\n' "$EVENTS" | grep -F -c -e "$RUN_ID" || true)
    echo "PASS: found the correlation key in CloudWatch Logs after $ATTEMPT attempt(s)," \
      "$(( NOW - POLL_STARTED_AT ))s of polling ($MATCH_COUNT matching row(s))."

    # First field of the matched row is the event timestamp, unless the message itself spanned
    # rows (CloudWatch messages may contain newlines). Only report it when it looks like one.
    EVENT_TIME_MS=$(printf '%s' "$MATCH_ROW" | cut -f1)
    if [[ "$EVENT_TIME_MS" =~ ^[0-9]{13}$ ]]; then
      echo "      event timestamp:  $EVENT_TIME_MS (epoch ms)"
      echo "      start -> event:   $(( (EVENT_TIME_MS - START_TIME_MS) / 1000 ))s" \
        "(--start-time-ms to the event's own timestamp; this is mostly how long the put step took)"
      echo "      event -> queryable: at most $(( (NOW * 1000 - EVENT_TIME_MS) / 1000 ))s" \
        "(the ingestion lag this budget has to cover; an upper bound, since polling is discrete)"
    else
      echo "      (event timestamp not reported: the matched row was a message continuation)"
    fi
    exit 0
  fi

  NOW=$(date +%s)
  if (( NOW + DELAY > DEADLINE )); then
    break
  fi
  echo "Attempt $ATTEMPT: not found yet; sleeping ${DELAY}s ($(( DEADLINE - NOW ))s of budget left)."
  sleep "$DELAY"
  DELAY=$(( DELAY * 2 ))
  if (( DELAY > MAX_DELAY_SECONDS )); then
    DELAY=$MAX_DELAY_SECONDS
  fi
done

ELAPSED=$(( $(date +%s) - POLL_STARTED_AT ))
cat <<EOF
FAIL: the correlation key never appeared in CloudWatch Logs.

  searched for:     aws.otel.contract.run.id=$RUN_ID
                    (server-side prefilter "$PREFILTER_TERM", then an exact substring match)
  log group:        withheld — it is the CONTRACT_TEST_LOG_GROUP secret of the \`put-to-get\`
                    GitHub environment. Read that secret's value to query the group by hand.
  region:           $REGION
  events at/after:  $START_TIME_MS (epoch ms)
  attempts:         $ATTEMPT over ${ELAPSED}s (budget ${TIMEOUT_SECONDS}s)

This is not a bare timeout: the fetch side worked (no AccessDenied, no ResourceNotFound), so the
key was genuinely absent from the group for the whole budget. Likely causes, in order:
  1. The put step exported but the data plane rejected or dropped the payload. Check the contract
     test step's output for non-2xx export responses.
  2. Ingestion is slower than the ${TIMEOUT_SECONDS}s budget. Re-run and compare; if it passes on a
     longer budget, raise --timeout-seconds rather than treating this as a payload bug.
  3. The resource attribute did not survive into the payload, so the key is not in the events at
     all. Reproduce hermetically: run the harness with --endpoint http://localhost:3000 and
     --run-id \$KEY and grep Examples/AwsOtelUI/out for the key.
  4. The put and get sides disagree on the key. Compare this value with the "Correlation key:"
     line printed by scripts/run-contract-tests.sh.
EOF
exit 1
