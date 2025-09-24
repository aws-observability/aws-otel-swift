#!/bin/bash

TEST_APP_APPLAUNCH_DURATION=$(grep "Duration (AppLaunch)" /tmp/SimpleAwsDemo/performanceTests/output | sed 's/.*(\([0-9.]*\) s.*/\1/')

BASELINE_APP_APPLAUNCH_DURATION=$(grep "Duration (AppLaunch)" /tmp/BaselineSimpleAwsDemo/performanceTests/output | sed 's/.*(\([0-9.]*\) s.*/\1/')

DIFF=$(echo "$TEST_APP_APPLAUNCH_DURATION - $BASELINE_APP_APPLAUNCH_DURATION" | bc -l)

if (( $(echo "$DIFF > 0.5" | bc -l) )); then
    echo "FAIL: App launch duration $TEST_APP_APPLAUNCH_DURATION s exceeds baseline $BASELINE_APP_APPLAUNCH_DURATION s by more than 500ms"
    exit 1
else
    echo "PASS: App launch duration $TEST_APP_APPLAUNCH_DURATION s is within acceptable range of baseline $BASELINE_APP_APPLAUNCH_DURATION s"
    exit 0
fi
