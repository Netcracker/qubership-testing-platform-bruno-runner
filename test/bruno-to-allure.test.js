#!/usr/bin/env node
/* global require, process, __dirname, console */
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const fixture = path.join(root, "test", "fixtures", "v4-bruno-report.json");
const converter = path.join(root, "scripts", "tools", "bruno-to-allure.js");
const outDir = fs.mkdtempSync(path.join(os.tmpdir(), "bruno-to-allure-v4-"));

try {
  const run = spawnSync(process.execPath, [converter, fixture, outDir, "smoke-collection"], {
    encoding: "utf8",
  });
  assert.equal(run.status, 0, `${run.stdout}\n${run.stderr}`);

  const resultFiles = fs.readdirSync(outDir).filter((file) => file.endsWith("-result.json"));
  assert.equal(resultFiles.length, 2);

  const results = Object.fromEntries(
    resultFiles.map((file) => {
      const result = JSON.parse(fs.readFileSync(path.join(outDir, file), "utf8"));
      return [result.name, result];
    })
  );

  const passed = results["Get Status"];
  assert.equal(passed.status, "passed");
  assert.ok(passed.labels.some((label) => label.name === "suite" && label.value === "smoke-collection"));
  assert.ok(passed.labels.some((label) => label.name === "subSuite" && label.value === "folder-a"));
  assert.equal(passed.parameters.find((parameter) => parameter.name === "Method").value, "GET");

  const failed = results["Get JSON"];
  assert.equal(failed.status, "failed");
  assert.match(failed.statusDetails.message, /status is 200/);
  assert.match(failed.statusDetails.trace, /expected 503 to equal 200/);
  assert.equal(failed.steps.find((step) => step.name === "status is 200").status, "failed");

  assert.ok(!passed.steps.some((step) => step.attachments));
  const attachments = failed.steps.flatMap((step) => step.attachments || []);
  assert.deepEqual(attachments.map((a) => a.name), ["Request", "Response"]);
  const response = JSON.parse(fs.readFileSync(path.join(outDir, attachments[1].source), "utf8"));
  assert.equal(response.status, 503);
  assert.equal(response.headers["content-type"], "text/html");
  assert.match(response.responseBody, /503 Service Temporarily Unavailable/);

  assert.equal(fs.readdirSync(outDir).filter((f) => f.endsWith("-container.json")).length, 0);
  assert.equal(fs.readdirSync(outDir).filter((f) => f !== "executor.json").length, 4);

  const debugDir = fs.mkdtempSync(path.join(os.tmpdir(), "bruno-to-allure-debug-"));
  try {
    const debugRun = spawnSync(process.execPath, [converter, fixture, debugDir, "smoke-collection"], {
      encoding: "utf8",
      env: { ...process.env, DEBUG_HTTP_MODE: "true" },
    });
    assert.equal(debugRun.status, 0, `${debugRun.stdout}\n${debugRun.stderr}`);
    assert.equal(
      fs.readdirSync(debugDir).filter((f) => /-(request|response)\.json$/.test(f)).length,
      4
    );
  } finally {
    fs.rmSync(debugDir, { recursive: true, force: true });
  }
  assert.ok(fs.existsSync(path.join(outDir, "executor.json")));

  console.log("Bruno V4 JSON-to-Allure conversion test passed");
} finally {
  fs.rmSync(outDir, { recursive: true, force: true });
}
