#!/bin/bash

# iOS Crash Report Symbolication Script
# 
# This script symbolicates iOS crash reports by:
# 1. Converting memory addresses to function names using dSYM files
# 2. Demangling Swift symbols to human-readable format
# 3. Handling both main binaries and debug.dylib files
#
# Requirements:
# - macOS with Xcode command line tools (atos, swift)
# - dSYM file matching the crashed binary
# - Crash report file (.crash)
#
# Output:
# - Creates <original_name>.symbolicated.crash with readable function names
# - Only symbolicates your app's code, not system libraries
# - Preserves original crash report structure

# Parse named arguments
CRASH_FILE=""
DSYM_FILE=""
ARCH="arm64"

while [[ $# -gt 0 ]]; do
    case $1 in
        --crash|-c)
            CRASH_FILE="$2"
            shift 2
            ;;
        --dsym|-d)
            DSYM_FILE="$2"
            shift 2
            ;;
        --arch|-a)
            ARCH="$2"
            shift 2
            ;;
        --help|-h)
            echo "iOS Crash Report Symbolication Tool"
            echo ""
            echo "Usage: $0 --crash <file> --dsym <file> [--arch <arch>]"
            echo ""
            echo "Options:"
            echo "  -c, --crash <file>  Path to .crash file"
            echo "  -d, --dsym <file>   dSYM file or binary name"
            echo "  -a, --arch <arch>   Target architecture (default: arm64)"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --crash report.crash --dsym AwsHackerNewsDemo"
            echo "  $0 -c crash.txt -d MyApp.app.dSYM -a arm64"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ -z "$CRASH_FILE" ] || [ -z "$DSYM_FILE" ]; then
    echo "Error: Missing required arguments"
    echo "Use --help for usage information"
    exit 1
fi

if [ ! -f "$CRASH_FILE" ]; then
    echo "Error: Crash file not found: $CRASH_FILE"
    exit 1
fi

# Check if dSYM exists as file, directory, or fallback path
DSYM_FALLBACK="$DSYM_FILE.app.dSYM/Contents/Resources/DWARF/$DSYM_FILE"
if [ ! -d "$DSYM_FILE" ] && [ ! -f "$DSYM_FILE" ] && [ ! -f "$DSYM_FALLBACK" ]; then
    echo "Error: dSYM file not found: $DSYM_FILE"
    echo "Tried: $DSYM_FILE, $DSYM_FALLBACK"
    exit 1
fi

OUTPUT_FILE="${CRASH_FILE%.crash}.symbolicated.crash"

# Extract binary name and load address from crash report
BINARY_NAME=$(basename "$DSYM_FILE" .app.dSYM)
LOAD_ADDRESS=$(grep -E "^0x[0-9a-f]+ - 0x[0-9a-f]+ $BINARY_NAME" "$CRASH_FILE" | head -1 | awk '{print $1}')

# If main binary not found, try debug.dylib or extract from stack traces
if [ -z "$LOAD_ADDRESS" ]; then
    DEBUG_BINARY="$BINARY_NAME.debug.dylib"
    LOAD_ADDRESS=$(grep -E "^0x[0-9a-f]+ - 0x[0-9a-f]+ $DEBUG_BINARY" "$CRASH_FILE" | head -1 | awk '{print $1}')
    if [ -z "$LOAD_ADDRESS" ]; then
        # Try to extract load address from main binary stack traces
        MAIN_ENTRY=$(grep -E "$BINARY_NAME.*0x" "$CRASH_FILE" | head -1)
        if [ -n "$MAIN_ENTRY" ]; then
            LOAD_ADDRESS=$(echo "$MAIN_ENTRY" | awk '{print $4}')
            if [ -n "$LOAD_ADDRESS" ]; then
                echo "Found load address from stack trace: $LOAD_ADDRESS"
            fi
        else
            # Fallback for debug.dylib
            DEBUG_ENTRY=$(grep "$DEBUG_BINARY" "$CRASH_FILE" | head -1 | awk '{print $3}')
            if [ -n "$DEBUG_ENTRY" ]; then
                LOAD_ADDRESS="0x1005d0000"
                BINARY_NAME="$DEBUG_BINARY"
            fi
        fi
    else
        BINARY_NAME="$DEBUG_BINARY"
    fi
fi

if [ -z "$LOAD_ADDRESS" ]; then
    echo "Error: Could not find load address for binary in crash report"
    exit 1
fi

# Find all addresses that belong to our binary and symbolicate them
DSYM_PATH="$DSYM_FILE"
if [ ! -f "$DSYM_PATH" ]; then
    DSYM_PATH="$DSYM_FILE.app.dSYM/Contents/Resources/DWARF/$DSYM_FILE"
fi

# Verify UUID match between crash report and dSYM
CRASH_UUID=$(grep -E "^0x[0-9a-f]+ - 0x[0-9a-f]+ $BINARY_NAME.*<.*>" "$CRASH_FILE" | sed 's/.*<\(.*\)>.*/\1/' | head -1)
DSYM_UUID=$(dwarfdump --uuid "$DSYM_PATH" 2>/dev/null | grep "$ARCH" | awk '{print $2}' | head -1)

# Normalize UUIDs for comparison (remove dashes, convert to lowercase)
CRASH_UUID_NORM=$(echo "$CRASH_UUID" | tr -d '-' | tr '[:upper:]' '[:lower:]')
DSYM_UUID_NORM=$(echo "$DSYM_UUID" | tr -d '-' | tr '[:upper:]' '[:lower:]')

if [ -n "$CRASH_UUID" ] && [ -n "$DSYM_UUID" ]; then
    if [ "$CRASH_UUID_NORM" = "$DSYM_UUID_NORM" ]; then
        echo "✅ UUID match: $CRASH_UUID"
    else
        echo "⚠️  UUID mismatch!"
        echo "   Crash report: $CRASH_UUID"
        echo "   dSYM file:    $DSYM_UUID"
        echo "   Continuing anyway..."
    fi
else
    echo "ℹ️  Could not verify UUID (crash: $CRASH_UUID, dSYM: $DSYM_UUID)"
fi

echo "Symbolicating $CRASH_FILE with $DSYM_FILE (arch: $ARCH, load: $LOAD_ADDRESS)"

# Copy original crash file
cp "$CRASH_FILE" "$OUTPUT_FILE"
COUNT=0
while read line; do
    ADDRESS=$(echo "$line" | awk '{print $3}')
    if [[ "$ADDRESS" =~ ^0x[0-9a-f]+$ ]]; then
        SYMBOL=$(atos -arch "$ARCH" -o "$DSYM_PATH" -l "$LOAD_ADDRESS" "$ADDRESS" 2>/dev/null)
        if [ "$SYMBOL" != "$ADDRESS" ] && [ -n "$SYMBOL" ]; then
            sed -i '' "s|$ADDRESS|$ADDRESS $SYMBOL|g" "$OUTPUT_FILE"
            COUNT=$((COUNT + 1))
        fi
    fi
done < <(grep -E "^\s*[0-9]+\s+$BINARY_NAME" "$CRASH_FILE")
echo "Symbolicated $COUNT addresses"

# Demangle Swift symbols in the output
SWIFT_COUNT=0
while read MANGLED; do
    if [ -n "$MANGLED" ]; then
        DEMANGLED=$(swift demangle "$MANGLED" 2>/dev/null | tail -1)
        if [ "$DEMANGLED" != "$MANGLED" ] && [ -n "$DEMANGLED" ]; then
            sed -i '' "s|$MANGLED|$MANGLED ($DEMANGLED)|g" "$OUTPUT_FILE"
            SWIFT_COUNT=$((SWIFT_COUNT + 1))
        fi
    fi
done < <(grep -oE '\$s[A-Za-z0-9_]+' "$OUTPUT_FILE" | sort -u)
echo "Demangled $SWIFT_COUNT Swift symbols"

echo "Symbolicated crash report saved to: $OUTPUT_FILE"
echo ""
echo "Summary:"
echo "- Processed crash report: $CRASH_FILE"
echo "- Used dSYM: $DSYM_FILE"
echo "- Architecture: $ARCH"
echo "- Binary load address: $LOAD_ADDRESS"
echo "- Symbolicated addresses: $COUNT"
echo "- Demangled Swift symbols: $SWIFT_COUNT"
echo ""
echo "Next steps:"
echo "- Review symbolicated crash report for readable function names"
echo "- Focus on frames from your app ($BINARY_NAME)"
echo "- System library frames (UIKit, Foundation) cannot be symbolicated"