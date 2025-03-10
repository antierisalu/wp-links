#!/bin/bash

# Download directory
if [ $PWD = "/var/www/html" ]; then
    DOWNLOAD_DIR="/var/www/html/wp-content/uploads/dld"
    echo "DOWNLOAD_DIR: $DOWNLOAD_DIR"
    sleep 3
else
    DOWNLOAD_DIR="/home/113628.cloudwaysapps.com/wsmkcneumj/public_html/wp-content/uploads/dld"
    echo "DOWNLOAD_DIR: $DOWNLOAD_DIR"
    sleep 3
fi

# Mapping file from previous script
MAPPING_FILE="pdf_mappings.txt"

# Ensure download directory exists
mkdir -p "$DOWNLOAD_DIR"

# Check if mapping file exists
if [ ! -f "$MAPPING_FILE" ]; then
    echo "Error: Mapping file $MAPPING_FILE not found."
    echo "Please run the mapping script first."
    exit 1
fi

# Count total files for progress reporting
total_files=$(wc -l < "$MAPPING_FILE")
current=0
successful=0
failed=0
skipped=0

echo "Starting download of $total_files PDF files to $DOWNLOAD_DIR"
echo "----------------------------------------"

# Process each line in the mapping file
while IFS=$'\t' read -r url post_id filename; do
    current=$((current + 1))
    
    # Get clean filename (handle URL encoding if needed)
    clean_filename=$(basename "$filename")
    
    echo -n "[$current/$total_files] Downloading: $clean_filename ... "
    
    # Check if file already exists
    if [ -f "$DOWNLOAD_DIR/$clean_filename" ]; then
        echo "SKIPPED (already exists)"
        skipped=$((skipped + 1))
        continue
    fi
    
    # Download the file
    if curl -s -L -o "$DOWNLOAD_DIR/$clean_filename" "$url"; then
        # Verify download
        if [ -f "$DOWNLOAD_DIR/$clean_filename" ] && [ -s "$DOWNLOAD_DIR/$clean_filename" ]; then
            echo "SUCCESS"
            successful=$((successful + 1))
        else
            echo "FAILED (empty file downloaded)"
            failed=$((failed + 1))
            # Clean up empty file
            rm -f "$DOWNLOAD_DIR/$clean_filename"
        fi
    else
        echo "FAILED (download error)"
        failed=$((failed + 1))
    fi
    
    # Brief pause to avoid hammering the server
    sleep 0.2
    
done < "$MAPPING_FILE"

echo "----------------------------------------"
echo "Download complete!"
echo "Total files: $total_files"
echo "Successfully downloaded: $successful"
echo "Failed: $failed"
echo "Skipped (already exist): $skipped"
echo "Files saved to: $DOWNLOAD_DIR"