#!/bin/bash

# Single MXF file converter script
# Called by the main script for each file
# Usage: ./convert_single_mxf.sh SOURCE_DIR OUTPUT_DIR file

SOURCE_DIR="$1"
OUTPUT_DIR="$2"
file="$3"

# Get the path relative to the source directory
# This removes the SOURCE_DIR prefix from the file path
relative_path="${file#"$SOURCE_DIR"/}"

# Get the directory part of the relative path
relative_dir=$(dirname "$relative_path")

# Get the base name of the file (without path and extension)
filename=$(basename -- "$file")
filename_no_ext="${filename%.*}"

# Define the full output directory for the current file, preserving subfolder structure
CURRENT_OUTPUT_DIR="$OUTPUT_DIR/$relative_dir"

# Create the specific output directory for this file if it doesn't exist
if [ ! -d "$CURRENT_OUTPUT_DIR" ]; then
    echo "Creating output sub-directory: $CURRENT_OUTPUT_DIR"
    mkdir -p "$CURRENT_OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create output sub-directory. Skipping '$file'."
        exit 1
    fi
fi

# Define the output MP4 file path
output_mp4="$CURRENT_OUTPUT_DIR/${filename_no_ext}.mp4"

echo "Converting '$file' to '$output_mp4'..."

ffmpeg -i "$file" -c:v libx264 -preset ultrafast -crf 18 -c:a aac -b:a 320k "$output_mp4" >/dev/tty 2>&1

if [ $? -eq 0 ]; then
    echo "Successfully converted '$file'."
else
    echo "Error converting '$file'. See ffmpeg output above for details."
fi
echo "----------------------------------------------------"