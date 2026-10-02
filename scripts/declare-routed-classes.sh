#!/usr/bin/env bash
set -euo pipefail

# Declare the root and all 14 facet classes one routed deployment needs, then
# print the GAME_CLASS_HASH and FACET_CLASS_HASHES values for Doppler. Run
# deploy-routed-game.sh afterwards with the same network and Doppler config.
CLASSES=(
  GameRoundActionsFacet GameRoundViewsFacet
  GameHideActionsFacet GameHideViewsFacet
  GameFinderValidationFacet GameFinderActionsFacet GameFinderViewsFacet
  GameUsdcClaimsFacet GameRozClaimsFacet
  GameSettingsActionsFacet GameSettingsViewsFacet
  GameTreasuryFacet GameAdminUpgradeFacet GameAdminActionsFacet
  HelloStarknet
)

usage() {
  cat <<'USAGE'
Usage: bash scripts/declare-routed-classes.sh [--network sepolia|mainnet]
       [--doppler-config NAME] [--dry-run|--send]

Defaults to a Sepolia dry-run using Doppler config dev. Mainnet requires an
explicit --doppler-config. Classes already declared on the network are skipped.
--send submits one fee-bearing declaration per missing class; without it, no
transaction is sent. Run scarb --release build first.
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
printf 'Routed class %s on %s using Doppler config %s.\n' \
  "$([[ "$mode" == dry ]] && printf 'dry-run' || printf 'declaration')" \
  "$network" "$doppler_config"

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
  node scripts/check-contract-env.mjs classes --online

  results=$(bash scripts/declare-classes.sh "$mode" "$@")
  game_hash=
  facets=()
  pending=0
  while read -r class hash state; do
    [[ "$state" == pending ]] && pending=$((pending + 1))
    if [[ "$class" == HelloStarknet ]]; then game_hash=$hash; else facets+=("$hash"); fi
  done <<< "$results"

  printf "\nDoppler %s values for deploy-routed-game.sh:\n" "$config"
  printf "GAME_CLASS_HASH=%s\n" "$game_hash"
  printf "FACET_CLASS_HASHES=\"%s\"\n" "${facets[*]}"
  if ((pending > 0)); then
    printf "\n%d class(es) are not declared on %s yet. Re-run with --send to declare them.\n" \
      "$pending" "$network"
  fi
' _ "$network" "$doppler_config" "$mode" "${CLASSES[@]}"
