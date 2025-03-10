#!/bin/bash

# Directory containing your downloaded PDFs
if [ $pwd = "/var/www/html" ]; then
    PDF_DIR="/var/www/html/wp-content/uploads/dld"
    echo "PDF_DIR: $PDF_DIR"
    sleep 3
else
    PDF_DIR="/home/113628.cloudwaysapps.com/wsmkcneumj/public_html/wp-content/uploads/dld"
    echo "PDF_DIR: $PDF_DIR"
    sleep 3
fi

# Output file for media mappings
MEDIA_MAP_FILE="media_library_map.txt"

# Clear or create the media mapping file
> "$MEDIA_MAP_FILE"

# Count files for progress reporting
total_files=$(find "$PDF_DIR" -name "*.pdf" | wc -l)
current=0
successful=0
failed=0

echo "Starting import of $total_files PDF files to WordPress Media Library"
echo "----------------------------------------"

# Process each PDF file
find "$PDF_DIR" -name "*.pdf" | while read -r pdf; do
    current=$((current + 1))
    filename=$(basename "$pdf")
    
    echo "[$current/$total_files] Importing: $filename"
    
    # Import file to media library and capture full output
    import_output=$(wp media import "$pdf" --allow-root 2>&1)
    import_status=$?
    
    if [ $import_status -eq 0 ]; then
        # Extract the media ID directly from import output using the specific pattern
        media_id=$(echo "$import_output" | grep -o "as attachment ID [0-9]*" | grep -o "[0-9]*")
        
        if [ -n "$media_id" ]; then
            # Get the media URL
            media_url=$(wp post get "$media_id" --field=guid --allow-root)
            
            echo "  Success! Media ID: $media_id"
            echo "  Media URL: $media_url"
            
            # Save mapping to file
            echo -e "$filename\t$media_id\t$media_url" >> "$MEDIA_MAP_FILE"
            
            successful=$((successful + 1))
        else
            echo "  Failed to get Media ID. Import output was: $import_output"
            failed=$((failed + 1))
        fi
    else
        echo "  Import failed with status $import_status: $import_output"
        failed=$((failed + 1))
    fi
    
    echo "----------------------------------------"
done

echo "Import complete!"
echo "Total files processed: $total_files"
echo "Successfully imported: $successful"
echo "Failed imports: $failed"
echo "Media mapping saved to: $MEDIA_MAP_FILE"