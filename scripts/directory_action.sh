#!/bin/bash

# Perform action on all file matching 'find' command
# Usage: ./directory_action.sh [source_directory] [output_directory] [match_pattern] [action_script]

# Define log file
LOG_DIR="./directory_action_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/directory_action_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to echo with timestamp
log_echo() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $@"
}

log_echo "Script output is being logged to: $LOG_FILE"

# Determine the source directory
if [ -z "$1" ]; then
    read -p "No source directory provided. Enter source directory (default: current directory): " SOURCE_DIR
    if [ -z "$SOURCE_DIR" ]; then
        SOURCE_DIR="."
    fi
    log_echo "Searching files in: $SOURCE_DIR"
else
    SOURCE_DIR="$1"
    log_echo "Searching files in: $SOURCE_DIR"
fi

# If the second argument is not provided, default to the current directory
if [ -z "$2" ]; then
    read -p "No output directory provided. Enter output directory (default: current directory): " OUTPUT_DIR
    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="."
    fi
    log_echo "Using output directory: $OUTPUT_DIR"
else
    OUTPUT_DIR="$2"
    log_echo "Using output directory: $OUTPUT_DIR"
fi

# Expand ~ in OUTPUT_DIR to the home directory
OUTPUT_DIR=$(eval echo "$OUTPUT_DIR")

# Resolve SOURCE_DIR to an absolute path for consistent path manipulation
SOURCE_DIR=$(cd "$SOURCE_DIR" && pwd)

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_echo "Error: Source directory '$SOURCE_DIR' not found."
    exit 1
fi

# Create the base output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    log_echo "Creating base output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        log_echo "Error: Could not create base output directory. Please check permissions."
        exit 1
    fi
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Determine the match pattern
if [ -z "$3" ]; then
    read -p "Enter match pattern: " MATCH_PATTERN_INPUT
    if [ -z "$MATCH_PATTERN_INPUT" ]; then
        echo "No match pattern provided, aborting."
        exit 1
    else
        MATCH_PATTERN="$MATCH_PATTERN_INPUT"
    fi
else
    MATCH_PATTERN="$3"
    log_echo "Using match pattern: $MATCH_PATTERN"
fi

# Determine the action script
if [ -z "$4" ]; then
    read -p "Enter action script: " ACTION_SCRIPT_INPUT
    if [ -z "$ACTION_SCRIPT_INPUT" ]; then
        log_echo "No action provided, aborting."
        exit 1
    else
        ACTION_SCRIPT="$ACTION_SCRIPT_INPUT"
    fi
else
    ACTION_SCRIPT="$4"
    log_echo "Using action script: $ACTION_SCRIPT"
fi

# Count files that match the pattern
FILE_COUNT=$(find "$SOURCE_DIR" \( -name ".*" -prune \) -o -type f -iname "$MATCH_PATTERN" | wc -l)
log_echo "Found $FILE_COUNT files matching pattern '$MATCH_PATTERN'."

log_echo "Starting script: $ACTION_SCRIPT on found files..."

# Find all .mxf files and call the action script for each one
find "$SOURCE_DIR" \( -name ".*" -prune \) -o -type f -iname "$MATCH_PATTERN" -exec bash -c '"$3" "$1" "$2" "$0" | sed "s/^/    /"' {} "$SOURCE_DIR" "$OUTPUT_DIR" "$ACTION_SCRIPT" \;

log_echo "Script: $ACTION_SCRIPT has been run on all found files."