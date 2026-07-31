#!/bin/bash
set -euo pipefail

# Requires a running Docker daemon. Run from repository root.
IMAGE="${BRUNO_SMOKE_IMAGE:-bruno-runner:v4-smoke}"
OUT_DIR="$(mktemp -d)"

docker build -t "${IMAGE}" .

docker run --rm \
  --entrypoint bash \
  -v "$(pwd)/test/fixtures/smoke-collection:/collection:ro" \
  -v "$(pwd)/scripts/tools/bruno-to-allure.js:/scripts/tools/bruno-to-allure.js:ro" \
  -v "${OUT_DIR}:/smoke-out" \
  "${IMAGE}" \
  -lc '
    set -euo pipefail
    cd /collection
    node -e "
      const http=require(\"http\");
      http.createServer((req,res)=>{
        const body=req.url===\"/status/200\"?{ok:true}:{slideshow:{title:\"sample\"}};
        res.writeHead(200,{\"content-type\":\"application/json\"});
        res.end(JSON.stringify(body));
      }).listen(9876,\"127.0.0.1\");
    " &
    server_pid=$!
    trap "kill ${server_pid}" EXIT
    sleep 1
    "${BRU_BIN}/bru.js" run --insecure --env default --reporter-json /smoke-out/report.json
    node /scripts/tools/bruno-to-allure.js /smoke-out/report.json /smoke-out/allure-results smoke-collection
    test "$(ls /smoke-out/allure-results/*-result.json | wc -l)" -eq 2
  '

echo "Container smoke artifacts: ${OUT_DIR}"
