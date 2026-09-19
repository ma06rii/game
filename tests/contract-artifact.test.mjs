import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { inspectClassArtifact } from "../scripts/check-class-artifact.mjs";

function withArtifacts(sierraVersion, casmFelts, run) {
  const directory = mkdtempSync(path.join(os.tmpdir(), "roz-class-check-"));
  const prefix = path.join(directory, "project_name_HelloStarknet");
  writeFileSync(
    `${prefix}.contract_class.json`,
    JSON.stringify({ sierra_program: sierraVersion.map((value) => `0x${value.toString(16)}`) }),
  );
  writeFileSync(
    `${prefix}.compiled_contract_class.json`,
    JSON.stringify({ bytecode: Array(casmFelts).fill("0x0") }),
  );
  try {
    run(directory);
  } finally {
    rmSync(directory, { recursive: true });
  }
}

test("accepts a supported Sierra version and class within limits", () => {
  withArtifacts([1, 9, 0], 8, (directory) => {
    const result = inspectClassArtifact(directory);
    assert.equal(result.versionText, "1.9.0");
    assert.equal(result.casmFelts, 8);
    assert.equal(result.declarationCodeGasFloor, 440_000);
    assert.deepEqual(result.problems, []);
    assert.deepEqual(result.warnings, []);
  });
});

test("rejects the old Cairo 2.20 Sierra artifact even when it is small", () => {
  withArtifacts([1, 9, 3], 8, (directory) => {
    assert.match(inspectClassArtifact(directory).problems[0], /Sierra 1\.9\.3/);
  });
});

test("rejects a class whose CASM exceeds the published limit", () => {
  withArtifacts([1, 9, 0], 81_921, (directory) => {
    assert.match(inspectClassArtifact(directory).problems[0], /CASM exceeds 81920 felts/);
  });
});

test("rejects a Sierra JSON artifact larger than the published limit", () => {
  withArtifacts([1, 9, 0], 8, (directory) => {
    writeFileSync(
      path.join(directory, "project_name_HelloStarknet.contract_class.json"),
      JSON.stringify({ sierra_program: ["0x1", "0x9", "0x0"], padding: "x".repeat(4_089_446) }),
    );
    assert.match(inspectClassArtifact(directory).problems[0], /Sierra JSON exceeds 4089446 bytes/);
  });
});

test("warns when declaration code data alone exceeds the published transaction cap", () => {
  withArtifacts([1, 9, 0], 27_498, (directory) => {
    const result = inspectClassArtifact(directory);
    assert.equal(result.problems.length, 0);
    assert.match(result.warnings[0], /above Starknet's published mainnet per-transaction limit/);
  });
});
