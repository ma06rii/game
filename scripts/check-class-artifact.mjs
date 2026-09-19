import { readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

// Starknet's published class limits. Keep the Sepolia compiler-version check
// separate: a class can be small enough and still be impossible to declare.
const MAX_CASM_FELTS = 81_920;
const MAX_SIERRA_BYTES = 4_089_446;
const SEPOLIA_SIERRA_VERSION = [1n, 9n, 0n];
// Starknet charges 40,000 L2 gas per Sierra/CASM code felt in a declaration.
// This is a floor, not a fee estimate: ABI and transaction overhead add more.
const DECLARE_CODE_GAS_PER_FELT = 40_000;
const PUBLISHED_MAINNET_MAX_TX_L2_GAS = 1_100_000_000;
const GAME_CLASSES = [
  "HelloStarknet",
  "GameRoundActionsFacet",
  "GameRoundViewsFacet",
  "GameHideActionsFacet",
  "GameHideViewsFacet",
  "GameFinderValidationFacet",
  "GameFinderActionsFacet",
  "GameFinderViewsFacet",
  "GameUsdcClaimsFacet",
  "GameRozClaimsFacet",
  "GameSettingsActionsFacet",
  "GameSettingsViewsFacet",
  "GameTreasuryFacet",
  "GameAdminUpgradeFacet",
  "GameAdminActionsFacet",
];

export function inspectClassArtifact(directory, contractName = "HelloStarknet") {
  const prefix = path.join(directory, `project_name_${contractName}`);
  const sierraPath = `${prefix}.contract_class.json`;
  const casmPath = `${prefix}.compiled_contract_class.json`;
  const sierra = JSON.parse(readFileSync(sierraPath, "utf8"));
  const casm = JSON.parse(readFileSync(casmPath, "utf8"));

  if (!Array.isArray(sierra.sierra_program) || sierra.sierra_program.length < 3) {
    throw new Error(`${contractName}: Sierra artifact has no version header`);
  }
  if (!Array.isArray(casm.bytecode)) {
    throw new Error(`${contractName}: CASM artifact has no bytecode`);
  }

  const version = sierra.sierra_program.slice(0, 3).map((value) => BigInt(value));
  const versionText = version.join(".");
  const sierraBytes = statSync(sierraPath).size;
  const sierraFelts = sierra.sierra_program.length;
  const casmFelts = casm.bytecode.length;
  const declarationCodeGasFloor = (sierraFelts + casmFelts) * DECLARE_CODE_GAS_PER_FELT;
  const problems = [];
  const warnings = [];

  if (version.some((value, index) => value !== SEPOLIA_SIERRA_VERSION[index])) {
    problems.push(
      `Sierra ${versionText} is not the pinned Sepolia version ${SEPOLIA_SIERRA_VERSION.join(".")}; rebuild with Scarb 2.19.0`,
    );
  }
  if (sierraBytes > MAX_SIERRA_BYTES) {
    problems.push(`Sierra JSON exceeds ${MAX_SIERRA_BYTES} bytes`);
  }
  if (casmFelts > MAX_CASM_FELTS) {
    problems.push(`CASM exceeds ${MAX_CASM_FELTS} felts`);
  }
  if (declarationCodeGasFloor > PUBLISHED_MAINNET_MAX_TX_L2_GAS) {
    warnings.push(
      `declaration code alone needs at least ${declarationCodeGasFloor} L2 gas, above Starknet's published mainnet per-transaction limit of ${PUBLISHED_MAINNET_MAX_TX_L2_GAS}; verify Sepolia's active limit before submitting`,
    );
  }

  return { contractName, versionText, sierraBytes, sierraFelts, casmFelts, declarationCodeGasFloor, problems, warnings };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const directory = path.resolve(process.argv[2] ?? "target/release");
  const names = process.argv.slice(3);
  const contracts = names.length ? names : GAME_CLASSES;
  let failed = false;

  for (const name of contracts) {
    try {
      const result = inspectClassArtifact(directory, name);
      process.stdout.write(
        `${name}: Sierra ${result.versionText}, ${result.sierraBytes} bytes; CASM ${result.casmFelts} felts; declaration code floor ${result.declarationCodeGasFloor} L2 gas\n`,
      );
      for (const problem of result.problems) {
        process.stderr.write(`ERROR: ${name}: ${problem}\n`);
      }
      for (const warning of result.warnings) {
        process.stderr.write(`WARNING: ${name}: ${warning}\n`);
      }
      failed ||= result.problems.length > 0;
    } catch (error) {
      process.stderr.write(`ERROR: ${name}: ${error.message}\n`);
      failed = true;
    }
  }

  if (failed) process.exitCode = 1;
}
