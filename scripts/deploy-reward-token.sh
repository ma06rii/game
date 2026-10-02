#!/usr/bin/env bash
set -euo pipefail

# Declare (if needed) and deploy the Zee Bucks (RZBX) reward token. The Cairo
# artifact keeps its legacy ROZToken name. The constructor is (recipient, owner)
# and mints the whole 5,000,000,000 RZBX supply to the recipient.

usage() {
  cat <<'USAGE'
Usage: bash scripts/deploy-reward-token.sh [--network sepolia|mainnet]
       [--doppler-config NAME] [--dry-run|--send]

Defaults to a Sepolia dry-run using Doppler config dev. Mainnet requires an
explicit --doppler-config. --send declares ROZToken if it is missing and then
deploys a new token; without it, no transaction is sent. Recipient and owner
come from ROZ_RECIPIENT_ADDRESS and ROZ_OWNER_ADDRESS in Doppler. Run
scarb --release build first.
USAGE
}

network=sepolia
mode=dry
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
    --dry-run) mode=dry; shift ;;
    --send) mode=send; shift ;;
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
printf 'Reward token %s on %s using Doppler config %s.\n' \
  "$([[ "$mode" == dry ]] && printf 'dry-run' || printf 'deployment')" \
  "$network" "$doppler_config"

# Expand constructor values only inside Varlock's child process. The private
# signing key remains in the local sncast account store, never in Doppler.
DOPPLER_CONFIG="$doppler_config" npm exec -- varlock run -- bash -c '
  set -euo pipefail
  network=$1
  config=$2
  mode=$3

  if [[ "${STARKNET_NETWORK:-}" != "$network" ]]; then
    echo "Doppler config $config targets ${STARKNET_NETWORK:-no network}, not $network." >&2
    exit 2
  fi
  # Also rejects a missing or zero recipient or owner address.
  node scripts/check-contract-env.mjs roz --online

  result=$(bash scripts/declare-classes.sh "$mode" ROZToken)
  read -r _ class_hash state <<< "$result"
  if [[ "$state" == pending ]]; then
    printf "\nROZToken is not declared on %s, so a deploy cannot be estimated yet.\n" "$network"
    printf "Re-run with --send to declare and deploy it.\n"
    exit 0
  fi

  printf "\n== Deploy ROZToken (%s)\n" "$class_hash"
  wait_flags=()
  dry_flags=()
  if [[ "$mode" == dry ]]; then
    dry_flags=(--dry-run --detailed)
  else
    wait_flags=(--wait --wait-timeout 600)
  fi
  sncast --account "$SNCAST_ACCOUNT" "${wait_flags[@]}" deploy "${dry_flags[@]}" \
    --url "$STARKNET_RPC_URL" --class-hash "$class_hash" \
    --constructor-calldata "$ROZ_RECIPIENT_ADDRESS" "$ROZ_OWNER_ADDRESS"

  if [[ "$mode" == send ]]; then
    printf "\nNext: set ROZ_TOKEN_ADDRESS in Doppler %s to the contract address above,\n" "$config"
    printf "then check name, symbol and total_supply with sncast call.\n"
  fi
' _ "$network" "$doppler_config" "$mode"
