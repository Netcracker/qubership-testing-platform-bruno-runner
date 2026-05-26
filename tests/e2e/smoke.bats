#!/usr/bin/env bats

load ../unit/test_helper

IMAGE="${BRUNO_RUNNER_IMAGE:-bruno-runner:test}"

@test "smoke: required binaries are on PATH" {
  run docker run --rm --entrypoint sh "$IMAGE" -c 'command -v bru && command -v jq && command -v curl && command -v s5cmd && command -v node && command -v bash'
  assert_success
}

@test "smoke: expected files / dirs exist in image" {
  run docker run --rm --entrypoint sh "$IMAGE" -c 'ls -la /app/package.json /app/node_modules/@usebruno/cli /scripts /scripts/tools /app/entrypoint.sh'
  assert_success
}

@test "smoke: container runs as uid 1007" {
  run docker run --rm --entrypoint id "$IMAGE" -u
  assert_success
  assert_output "1007"
}

@test "smoke: entrypoint reports missing env vars" {
  run docker run --rm "$IMAGE"
  # The EXIT trap intentionally exits 0 for Argo/K8s compatibility,
  # but init_environment must emit an error message for missing credentials.
  [[ "$output" == *"required"* || "$output" == *"must be set"* || "$output" == *"❌"* ]]
}
