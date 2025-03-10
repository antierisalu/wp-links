#!/bin/bash

# Input files
ORIGINAL_MAP="pdf_mappings.txt"
MEDIA_MAP="media_library_map.txt"

# Check if files exist
if [ ! -f "$ORIGINAL_MAP" ]; then
    echo "Error: Original mapping file $ORIGINAL_MAP not found."
    exit 1
fi

if [ ! -f "$MEDIA_MAP" ]; then
    echo "Error: Media mapping file $MEDIA_MAP not found."
    exit 1
fi

echo "Building URL replacement map..."

# Create a temporary lookup file for faster processing
LOOKUP_FILE="url_replacements.txt"
> "$LOOKUP_FILE"

# Build a lookup table of original URL to media URL
while IFS=$'\t' read -r filename media_id media_url; do
    # Find matching entries in the original mapping file
    grep -F "$filename" "$ORIGINAL_MAP" | while IFS=$'\t' read -r original_url post_id decoded_filename; do
        if [ -n "$original_url" ] && [ -n "$media_url" ]; then
            echo -e "$original_url\t$post_id\t$media_url" >> "$LOOKUP_FILE"
            echo "Will replace: $original_url -> $media_url in post ID $post_id"
        fi
    done
done < "$MEDIA_MAP"

# Count how many replacements we'll make
total_replacements=$(wc -l < "$LOOKUP_FILE")
echo "Found $total_replacements URLs to replace across posts"
echo "----------------------------------------"

# Track statistics
updated_posts=0
total_replacements_made=0
failed_updates=0

# Process each replacement
while IFS=$'\t' read -r original_url post_id media_url; do
    echo "Processing post ID: $post_id"
    
    # Get the post content
    content=$(wp post get "$post_id" --field=post_content --allow-root 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$content" ]; then
        echo "  Failed to get content for post ID $post_id"
        failed_updates=$((failed_updates + 1))
        continue
    fi
    
    # Check if the URL is in the content
    if echo "$content" | grep -q "$original_url"; then
        echo "  Found URL to replace"
        
        # Handle URLs that might have additional content after .pdf
        base_url=$(echo "$original_url" | sed 's/\.pdf.*/.pdf/')
        
        # Create a new content with the replacement
        new_content=$(echo "$content" | sed "s|$base_url[^\"' ]*|$media_url|g")
        
        # Count how many replacements were made
        replacements_made=$(echo "$new_content" | grep -o "$media_url" | wc -l)
        
        # Update the post if content changed
        if [ "$content" != "$new_content" ]; then
            echo "  Updating post with $replacements_made replacements"
            wp post update "$post_id" --post_content="$new_content" --allow-root
            
            if [ $? -eq 0 ]; then
                updated_posts=$((updated_posts + 1))
                total_replacements_made=$((total_replacements_made + replacements_made))
                echo "  Success!"
            else
                echo "  Failed to update post"
                failed_updates=$((failed_updates + 1))
            fi
        else
            echo "  No changes needed (URL not found or already replaced)"
        fi
    else
        echo "  URL not found in content (may have been already replaced)"
    fi
    
    echo "----------------------------------------"
done < "$LOOKUP_FILE"

echo "Update complete!"
echo "Posts updated: $updated_posts"
echo "Total replacements made: $total_replacements_made"
echo "Failed updates: $failed_updates"

# Clean up
rm -f "$LOOKUP_FILE"