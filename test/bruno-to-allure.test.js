#!/usr/bin/env node
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

  for (const stepName of ["Request Headers", "Request Body", "Response Headers", "Response Body"]) {
    const attachment = failed.steps.find((step) => step.name === stepName).attachments[0];
    assert.ok(fs.existsSync(path.join(outDir, attachment.source)), `missing ${stepName} attachment`);
  }

  const containerFiles = fs.readdirSync(outDir).filter((file) => file.endsWith("-container.json"));
  assert.equal(containerFiles.length, 1);
  assert.equal(
    JSON.parse(fs.readFileSync(path.join(outDir, containerFiles[0]), "utf8")).children.length,
    2
  );
  assert.ok(fs.existsSync(path.join(outDir, "executor.json")));

  console.log("Bruno V4 JSON-to-Allure conversion test passed");
} finally {
  fs.rmSync(outDir, { recursive: true, force: true });
}
