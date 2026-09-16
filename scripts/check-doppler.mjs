#!/usr/bin/env node

// This check deliberately runs OUTSIDE Varlock. `.env.schema` resolves
// DOPPLER_TOKEN from `doppler configure get token --plain`, so an unscoped
// Doppler CLI makes `varlock run` abort during schema initialization with
// `Referenced item "DOPPLER_TOKEN" is not valid`. check-contract-env.mjs cannot
// report that, because it is itself launched by the `varlock run` that died.

import { execFileSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const EXPECTED_PROJECT = "roz-contract";
const EXPECTED_CONFIG = "dev";

const SETUP_INSTRUCTIONS = [
  "doppler login                                     # once per machine",
  `doppler setup --project ${EXPECTED_PROJECT} --config ${EXPECTED_CONFIG} # once per checkout`,
].join("\n    ");

function runDoppler(args) {
  try {
    return execFileSync("doppler", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    if (error.code === "ENOENT") {
      throw new Error(
        "the Doppler CLI is not installed, but .env.schema resolves DOPPLER_TOKEN from it.\n" +
          "  Install it from https://docs.doppler.com/docs/install-cli, then:\n    " +
          SETUP_INSTRUCTIONS,
      );
    }
    return "";
  }
}

// `doppler configure --json` reports the scope for the current directory. An
// unconfigured CLI returns `{}`; a configured one nests the settings under the
// scope path it matched, so search every scope rather than assuming a key.
export function readDopplerScope(output) {
  let parsed;
  try {
    parsed = JSON.parse(output);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object") return null;

  for (const scope of Object.values(parsed)) {
    if (!scope || typeof scope !== "object") continue;
    const project = scope["enclave.project"] ?? scope.project;
    const config = scope["enclave.config"] ?? scope.config;
    if (project || config) return { project: project ?? null, config: config ?? null };
  }
  return null;
}

export function checkDoppler({ token, scopeOutput, serviceToken } = {}) {
  // CI supplies DOPPLER_TOKEN directly and never runs `doppler login`, so the
  // CLI has no token and no scope there. .env.schema accepts that path, so this
  // guard must not block it.
  if (serviceToken && serviceToken.trim() !== "") return [];

  const errors = [];
  const scope = readDopplerScope(scopeOutput ?? "");

  if (!token || token.trim() === "") {
    errors.push("no Doppler token is available for this directory");
  }
  if (!scope) {
    errors.push("the Doppler CLI has no project scope configured for this directory");
  } else {
    if (scope.project !== EXPECTED_PROJECT) {
      errors.push(`Doppler project is ${scope.project ?? "unset"}, expected ${EXPECTED_PROJECT}`);
    }
    if (scope.config !== EXPECTED_CONFIG) {
      errors.push(`Doppler config is ${scope.config ?? "unset"}, expected ${EXPECTED_CONFIG}`);
    }
  }
  return errors;
}

function main() {
  const serviceToken = process.env.DOPPLER_TOKEN;
  if (serviceToken && serviceToken.trim() !== "") return;

  const token = runDoppler(["configure", "get", "token", "--plain"]);
  const scopeOutput = runDoppler(["configure", "--json"]);
  const errors = checkDoppler({ token, scopeOutput, serviceToken });

  if (errors.length > 0) {
    throw new Error(
      `Doppler is not ready, so Varlock cannot resolve .env.schema:\n- ${errors.join("\n- ")}\n\n` +
        `  Fix with:\n    ${SETUP_INSTRUCTIONS}\n\n` +
        "  Without this, every varlock-wrapped sncast command fails before sncast runs.",
    );
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
