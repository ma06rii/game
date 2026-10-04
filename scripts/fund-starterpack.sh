#!/usr/bin/env bash
set -euo pipefail

# Top up TreasureGameStarterpack inventory (USDC, STRK, RZBX) to cover a target
# number of Welcome and Week sales. Wraps fund-starterpack.mjs with the same
# network and Doppler flags as the other deployment scripts.

usage() {
  cat <<'USAGE'
Usage: bash scripts/fund-starterpack.sh --welcome N [--week N]
       [--network sepolia|mainnet] [--doppler-config NAME]
       [--account ALIAS] [--dry-run|--send]

Makes the contract hold enough for N Welcome sales plus N Week units, using the
contract's live pack_amounts, and sends only each token's shortfall, so running
it again tops up rather than double-funding. Defaults to a Sepolia dry-run using
Doppler config dev; mainnet requires an explicit --doppler-config. Tokens come
from the sncast account --account, or STARTERPACK_OWNER_SNCAST_ACCOUNT, which
keeps 1 STRK back for gas. Without --send nothing is transferred.
USAGE
}

network=sepolia
doppler_config=dev
config_explicit=false
passthrough=()
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
    --dry-run|--send) passthrough+=("$1"); shift ;;
    --welcome|--week|--account)
      (($# >= 2)) || { usage >&2; exit 2; }
      passthrough+=("$1" "$2")
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
printf 'Starter pack funding on %s using Doppler config %s.\n' "$network" "$doppler_config"

DOPPLER_CONFIG="$doppler_config" npm exec -- varlock run -- bash -c '
  set -euo pipefail
  network=$1
  config=$2
  shift 2

  if [[ "${STARKNET_NETWORK:-}" != "$network" ]]; then
    echo "Doppler config $config targets ${STARKNET_NETWORK:-no network}, not $network." >&2
    exit 2
  fi

  # Print the STRK fee total on every exit, including a failure part-way through.
  FEE_LOG=$(mktemp)
  export FEE_LOG
  finish() { node scripts/sum-fees.mjs "$FEE_LOG" || true; rm -f "$FEE_LOG"; }
  trap finish EXIT

  node scripts/fund-starterpack.mjs "$@" | tee -a "$FEE_LOG"
' _ "$network" "$doppler_config" "${passthrough[@]}"
