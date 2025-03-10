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

# Output mapping file for other scripts to use
MAPPING_FILE="pdf_mappings.txt"

# Get all valid post IDs
post_ids=$(wp post list --post_type=page --status=publish --field=ID --allow-root)
updated_posts=0

echo "Starting to map PDF links..."

# First, process all posts to find PDF links
declare -A pdf_links
declare -A link_to_file_map

# Clear mapping file
> "$MAPPING_FILE"

for id in $post_ids; do
    # Skip if ID is not a valid number
    if ! echo "$id" | grep -qE '^[0-9]+$'; then
        continue
    fi
    
    content=$(wp post get "$id" --field=post_content --allow-root 2>/dev/null)
    if [ $? -ne 0 ]; then
        continue
    fi
    
    # Find all PDF links in the content
    urls=$(echo "$content" | grep -o 'https://[^\"]*\.pdf[^\"]*' | sed 's/\.pdf.*/\.pdf/')
    
    if [ -n "$urls" ]; then
        title=$(wp post get "$id" --field=post_title --allow-root)
        echo "Found PDF links in: $title (ID: $id)"
        
        echo "$urls" | while read -r url; do
            filename=$(basename "$url")
            decoded_filename=$(printf '%b' "${filename//%/\\x}")
            
            # Store the link to post mapping
            pdf_links["$url"]="$id"
            link_to_file_map["$url"]="$decoded_filename"
            
            # Save to mapping file: original_url, post_id, decoded_filename
            echo -e "$url\t$id\t$decoded_filename" >> "$MAPPING_FILE"
            
            echo "  Link: $url -> $decoded_filename"
        done
    fi
done

echo "Found ${#pdf_links[@]} unique PDF links."
echo "Mapping saved to $MAPPING_FILE"
echo "----------------------------------------"

# Now process each PDF file
for pdf in "$PDF_DIR"/*.pdf; do
    if [ ! -f "$pdf" ]; then
        continue
    fi
    
    filename=$(basename "$pdf")
    echo "Processing file: $filename"
    
    # Import this file to media library
    echo "Importing to media library..."
    import_result=$(wp media import "$pdf" --allow-root)
    
    if [ $? -ne 0 ]; then
        echo "Failed to import: $filename"
        continue
    fi
    
    media_id=$(echo "$import_result" | grep -o "ID: [0-9]*" | cut -d' ' -f2)
    
    if [ -z "$media_id" ]; then
        echo "Failed to get media ID for: $filename"
        continue
    fi
    
    # Get the media URL for this file
    media_url=$(wp post get "$media_id" --field=guid --allow-root)
    echo "Media URL: $media_url"
    
    # Save the media URL mapping to the file
    grep -P "\t$filename$" "$MAPPING_FILE" | while IFS=$'\t' read -r orig_url post_id decoded_filename; do
        echo -e "$orig_url\t$post_id\t$decoded_filename\t$media_url" >> "media_mappings.txt"
    done
    
    # Find which links should be replaced with this media URL
    for link in "${!link_to_file_map[@]}"; do
        mapped_file="${link_to_file_map[$link]}"
        
        # If the current PDF matches a link we found
        if [ "$filename" = "$mapped_file" ]; then
            post_id="${pdf_links[$link]}"
            echo "Found match: $link -> $media_url in post $post_id"
            
            # Update the post content
            content=$(wp post get "$post_id" --field=post_content --allow-root)
            
            # Handle both the normal link and any with extra content after .pdf
            base_link=$(echo "$link" | sed 's/\.pdf.*/.pdf/')
            new_content=$(echo "$content" | sed "s|$base_link[^\"' ]*|$media_url|g")
            
            if [ "$content" != "$new_content" ]; then
                wp post update "$post_id" --post_content="$new_content" --allow-root
                updated_posts=$((updated_posts + 1))
                echo "Updated post ID: $post_id"
            fi
        fi
    done
    
    echo "----------------------------------------"
done

echo "Link replacement complete! Updated $updated_posts posts."
echo "All mappings saved to pdf_mappings.txt and media_mappings.txt"