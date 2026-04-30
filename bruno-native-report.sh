#!/bin/bash

# Save Runner native report files to attachments
# Usage: save_native_report <source_path>
# Extracts folder name from path after $TMP_DIR and copies folder with its content to attachments
save_native_report() {
    echo "🔧 Skipping native report save for Bruno Runner (as it's not expected)"
    return 0
}
