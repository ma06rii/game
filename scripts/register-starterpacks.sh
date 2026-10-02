#!/usr/bin/env bash
set -euo pipefail

# Register the Welcome and Week packs in Cartridge Arcade and set their IDs on
# TreasureGameStarterpack. Wraps register-starterpacks.mjs with the same
# network and Doppler flags as the other deployment scripts.

usage() {
  cat <<'USAGE'
Usage: bash scripts/register-starterpacks.sh [--network sepolia|mainnet]
       [--doppler-config NAME] [--dry-run|--send]
       [--welcome-id N] [--week-id N]

Defaults to a Sepolia dry-run using Doppler config dev: it previews the pack
IDs and estimates every fee without sending anything. Mainnet requires an
explicit --doppler-config. --send registers both packs, signed by
STARTERPACK_OWNER_SNCAST_ACCOUNT, then calls set_pack_ids. If a run stopped
after registering a pack, pass its ID with --welcome-id or --week-id to reuse it
instead of registering a duplicate. Pack text and images come from
integrations/starterpacks/*.json.
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
    --welcome-id|--week-id)
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
printf 'Starter pack registration on %s using Doppler config %s.\n' "$network" "$doppler_config"

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

  node scripts/register-starterpacks.mjs "$@" | tee -a "$FEE_LOG"
' _ "$network" "$doppler_config" "${passthrough[@]}"
