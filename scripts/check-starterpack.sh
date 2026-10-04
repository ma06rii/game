#!/usr/bin/env bash
set -euo pipefail

# Read-only check of the deployed TreasureGameStarterpack: pack IDs, issued
# amounts, token addresses, minimum hide stake, Arcade registry, the two Arcade
# listings and the contract's inventory. Sends no transactions.

usage() {
  cat <<'USAGE'
Usage: bash scripts/check-starterpack.sh [--network sepolia|mainnet]
       [--doppler-config NAME]

Defaults to Sepolia using Doppler config dev. Mainnet requires an explicit
--doppler-config. Prints PASS, WARN or FAIL for each check and exits 1 if any
check fails. The contract comes from STARTERPACK_ADDRESS in Doppler.
USAGE
}

network=sepolia
doppler_config=dev
config_explicit=false
while (($#)); do
  case "$1" in
    --network)
      (($# >= 2)) || { usage >&2; exit 2; }
      network=$2
      shift 2
      ;;
    --doppler-config)
      (($# >= 2)) || { usage >&2; exit 2; }
      doppler_config=$2
      config_explicit=true
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$network" in
  sepolia|mainnet) ;;
  *) printf 'Network must be sepolia or mainnet.\n' >&2; exit 2 ;;
esac
if [[ "$network" == mainnet && "$config_explicit" != true ]]; then
  printf 'Mainnet requires an explicit --doppler-config NAME.\n' >&2
  exit 2
fi
if [[ ! "$doppler_config" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then
  printf 'Invalid Doppler config name.\n' >&2
  exit 2
fi

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"
printf 'Starter pack check on %s using Doppler config %s.\n\n' "$network" "$doppler_config"

DOPPLER_CONFIG="$doppler_config" npm exec -- varlock run -- bash -c '
  set -euo pipefail
  if [[ "${STARKNET_NETWORK:-}" != "$1" ]]; then
    echo "Doppler config $2 targets ${STARKNET_NETWORK:-no network}, not $1." >&2
    exit 2
  fi
  exec node scripts/check-starterpack.mjs
' _ "$network" "$doppler_config"
