#!/usr/bin/env bash
set -euo pipefail

# Check, estimate, apply or unpause the initial settings and price bands of a
# deployed routed game. Wraps initialize-routed-game.mjs with the same network
# and Doppler flags as the other deployment scripts.

usage() {
  cat <<'USAGE'
Usage: bash scripts/initialize-routed-game.sh [--network sepolia|mainnet]
       [--doppler-config NAME] [--check|--estimate|--send|--unpause]
       [--confirm-mainnet]

Defaults to a read-only Sepolia --check using Doppler config dev. Mainnet
requires an explicit --doppler-config, and --send or --unpause on prd also
requires --confirm-mainnet. --estimate only estimates fees. --send applies the
settings and bands as the admin, leaving the game paused. --unpause signs as the
pauser once everything matches. For stg/prd the game comes from GAME_ADDRESS.
USAGE
}

network=sepolia
mode=--check
doppler_config=dev
config_explicit=false
confirm=()
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
    --check|--estimate|--send|--unpause) mode=$1; shift ;;
    --confirm-mainnet) confirm=(--confirm-mainnet); shift ;;
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
printf 'Routed game initialization %s on %s using Doppler config %s.\n' \
  "${mode#--}" "$network" "$doppler_config"

DOPPLER_CONFIG="$doppler_config" npm exec -- varlock run -- bash -c '
  set -euo pipefail
  network=$1
  config=$2
  mode=$3
  shift 3

  if [[ "${STARKNET_NETWORK:-}" != "$network" ]]; then
    echo "Doppler config $config targets ${STARKNET_NETWORK:-no network}, not $network." >&2
    exit 2
  fi
  if [[ "$mode" == --check ]]; then
    exec node scripts/initialize-routed-game.mjs "$mode" "$@"
  fi

  # Print the STRK fee total on every exit, including a failure part-way through.
  FEE_LOG=$(mktemp)
  export FEE_LOG
  finish() { node scripts/sum-fees.mjs "$FEE_LOG" || true; rm -f "$FEE_LOG"; }
  trap finish EXIT

  node scripts/initialize-routed-game.mjs "$mode" "$@" | tee -a "$FEE_LOG"
' _ "$network" "$doppler_config" "$mode" "${confirm[@]}"
