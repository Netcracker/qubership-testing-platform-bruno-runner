#!/bin/bash
set -e

source /tools/bru_tools.sh

echo "ℹ️ Installed Bruno version: $(bru --version)"

# Main test job entrypoint script - coordinates all modules
echo "🔧 Starting test job entrypoint script..."
echo "📁 Working directory: $(pwd)"
echo "📅 Timestamp: $(date)"

# Set default upload method
export UPLOAD_METHOD="${UPLOAD_METHOD:-sync}"
echo "📤 Upload method: $UPLOAD_METHOD"

# Import modular components
source /scripts/init.sh
source /scripts/git-clone.sh
source /scripts/runtime-setup.sh
source /scripts/test-runner.sh
source /scripts/upload-monitor.sh
source /scripts/email-notification/generate-email-notification-json.sh

# Execute main workflow
echo "🚀 Starting test execution workflow..."

init_environment
clone_repository
setup_runtime_environment
start_upload_monitoring
cp -f /start_tests.sh $TMP_DIR/start_tests.sh
if ! local_run_enabled; then
    run_tests
else
    local_run_tests
fi
generate_email_notification_json
finalize_upload

echo "✅ Test job finished successfully!"
