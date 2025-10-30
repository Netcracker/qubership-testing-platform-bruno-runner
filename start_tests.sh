#!/bin/bash
set -e

source /tools/bru_tools.sh

## Check and extract input test parameters for Bruno
# Check if TEST_PARAMS is set
check_env_var "TEST_PARAMS" ""
# Extract Bruno environment file to a variable BRUNO_ENV_STR
extract_bruno_env "$TEST_PARAMS" "BRUNO_ENV_STR"
# Extract Bruno collections to an array variable BRUNO_COLLECTIONS_ARRAY
extract_bruno_collections "$TEST_PARAMS" "BRUNO_COLLECTIONS_ARRAY"
# Extract Bruno environment variables to a variable BRUNO_ENV_VARS_CLI
extract_bruno_env_vars "$TEST_PARAMS" "BRUNO_ENV_VARS_CLI"
# Extract Bruno flags to a variable BRUNO_FLAGS_CLI
extract_bruno_flags "$TEST_PARAMS" "BRUNO_FLAGS_CLI"

# ============================================
# Launching Bruno collections
# ============================================
echo "🚀 Launching Bruno collections"

# Move into the temp directory
cd $TMP_DIR

# Prepare Bruno launch
# Paths to results
PATH_TO_ATTACHMENTS_DIR="${TMP_DIR}/attachments"
PATH_TO_ALLURE_RESULTS="${TMP_DIR}/allure-results"

BRUNO_REPORTERS="--reporter-json"
BRUNO_REPORT_FILE="result.json"

mkdir -p "$PATH_TO_ATTACHMENTS_DIR"
mkdir -p "$PATH_TO_ALLURE_RESULTS"

# Run Bruno collection (directory)
# For each collection directory in BRUNO_COLLECTIONS_ARRAY
for collection_dir in "${BRUNO_COLLECTIONS_ARRAY[@]}"; do
    collection_path=${TMP_DIR}/${collection_dir}

    echo "➡️ Processing collection: $collection_path"

    if [ -d "$collection_path" ]; then
        collection_name=$(basename "$collection_dir")
        bruno_report_path="${PATH_TO_ATTACHMENTS_DIR}/${collection_name}-${BRUNO_REPORT_FILE}"

        # Print run command
        echo "📁 Running collection from: $collection_path"
        echo "🚀 bru run ${BRUNO_FLAGS_CLI} --env "${BRUNO_ENV_STR}" ${BRUNO_REPORTERS} "${html_report_path}" ${BRUNO_ENV_VARS_CLI}"
        echo "➡️ Bruno report will be saved to: ${bruno_report_path}"

        # Change to collection directory
        pushd "$collection_path" > /dev/null

        # Run Bruno collection
        if ! output=$(${BRU_BIN}/bru.js run ${BRUNO_FLAGS_CLI} \
            --env "${BRUNO_ENV_STR}" \
            ${BRUNO_ENV_VARS_CLI} \
            ${BRUNO_REPORTERS} "${bruno_report_path}" 2>&1);
        then
            echo "Output:"
            echo "$output"
            echo "❌ Bruno run failed for collection: $collection_name"
            #BRUNO_FAILED=1
        else
            echo "Output:"
            echo "$output"
            echo "✅ Bruno run succeeded for collection: $collection_name"
    fi
        # Return to previous directory
        popd > /dev/null
        # Convert Bruno JSON to Allure results
        if ! local_run_enabled; then
            node /tools/bruno-to-allure.js "${bruno_report_path}" "${PATH_TO_ALLURE_RESULTS}"
        else
            node $WORK_DIR/tools/bruno-to-allure.js "${bruno_report_path}" "${PATH_TO_ALLURE_RESULTS}"
        fi
    fi
done
