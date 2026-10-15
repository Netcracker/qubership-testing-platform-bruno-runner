#!/usr/bin/env node
/* global require, process, __dirname, console */
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const collection = path.join(root, "test", "fixtures", "smoke-collection");
const bru = path.join(root, "node_modules", "@usebruno", "cli", "bin", "bru.js");
const converter = path.join(root, "scripts", "tools", "bruno-to-allure.js");
const port = 9876;

function execute(command, args, options) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, options);
    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    child.on("error", reject);
    child.on("close", (code) => resolve({ code, output }));
  });
}

async function main() {
  assert.ok(fs.existsSync(bru), "Bruno CLI missing; run npm ci first");
  const server = http.createServer((request, response) => {
    const body = request.url === "/status/200" ? { ok: true } : { slideshow: { title: "sample" } };
    response.writeHead(200, { "content-type": "application/json" });
    response.end(JSON.stringify(body));
  });
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), "bruno-v4-smoke-"));
  const report = path.join(outDir, "report.json");
  const allure = path.join(outDir, "allure-results");
  fs.mkdirSync(allure);

  await new Promise((resolve) => server.listen(port, "127.0.0.1", resolve));
  try {
    // Same CLI flags used by scripts/lib/collection-runner.sh.
    const run = await execute(process.execPath, [
      bru, "run", "--insecure", "--env", "default", "--reporter-json", report,
    ], { cwd: collection });
    assert.equal(run.code, 0, run.output);
    assert.ok(fs.existsSync(report), "Bruno did not write a JSON report");

    const convert = await execute(process.execPath, [converter, report, allure, "smoke-collection"]);
    assert.equal(convert.code, 0, convert.output);

    const results = fs.readdirSync(allure)
      .filter((file) => file.endsWith("-result.json"))
      .map((file) => JSON.parse(fs.readFileSync(path.join(allure, file), "utf8")));
    assert.equal(results.length, 2);
    assert.ok(results.every((result) => result.status === "passed"));
    console.log(`Bruno V4 smoke validation passed (${require(path.join(root, "node_modules", "@usebruno", "cli", "package.json")).version})`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    fs.rmSync(outDir, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
