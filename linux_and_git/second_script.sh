#!/bin/bash
#this script moves all CSV and JSON files from the source directory to the destination directory
source_dir="./sources"
destination_dir="./json_and_csv"

# Create destination directory
mkdir -p "$destination_dir"

# Move CSV and JSON files
mv "$source_dir"/*.{csv,CSV,json,JSON} "$destination_dir/" 2>/dev/null
echo "CSV and JSON files moved."
