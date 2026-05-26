#!/usr/bin/env bats

# scripts/init.sh defines init_environment(). It requires ATP_STORAGE_USERNAME
# and ATP_STORAGE_PASSWORD to be set, otherwise it returns 1 with a clear msg.

load test_helper

setup() {
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/scripts/init.sh"
  unset ATP_STORAGE_USERNAME ATP_STORAGE_PASSWORD ATP_STORAGE_PROVIDER \
        ATP_STORAGE_REGION ATP_STORAGE_SERVER_URL CURRENT_DATE CURRENT_TIME || true
}

@test "init_environment: missing ATP_STORAGE_USERNAME => 1" {
  run init_environment
  assert_failure 1
  assert_output --partial "ATP_STORAGE_USERNAME is required"
}

@test "init_environment: missing ATP_STORAGE_PASSWORD => 1" {
  ATP_STORAGE_USERNAME=user run init_environment
  assert_failure 1
  assert_output --partial "ATP_STORAGE_PASSWORD is required"
}

@test "init_environment: success path sets AWS creds and TMP_DIR" {
  export ATP_STORAGE_USERNAME=user
  export ATP_STORAGE_PASSWORD=pass
  run init_environment
  assert_success
  assert_output --partial "Environment initialized successfully"
}

@test "init_environment: minio provider exports AWS_ENDPOINT_URL" {
  export ATP_STORAGE_USERNAME=user
  export ATP_STORAGE_PASSWORD=pass
  export ATP_STORAGE_PROVIDER=minio
  export ATP_STORAGE_SERVER_URL=http://minio:9000
  export ATP_STORAGE_REGION=us-east-1
  # Run in a subshell so the inherited exports stay; assert via a follow-up shell.
  run bash -c "
    source '${REPO_ROOT}/scripts/init.sh'
    init_environment >/dev/null
    echo \"\$AWS_ENDPOINT_URL|\$AWS_REGION|\$AWS_NO_VERIFY_SSL\"
  "
  assert_success
  assert_output --partial "http://minio:9000|us-east-1|true"
}
