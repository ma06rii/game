#!/usr/bin/env bash
set -euo pipefail

# Deploy one routed HelloStarknet instance. These are class hashes, not facet
# contract addresses; the facets are declared but are never deployed separately.
GAME_CLASS_HASH=0x05c62564e2163b40ed87e846bfb06fd79b11c1fd9a0719a2d4ea91e4022644df
FACET_HASHES=(
  0x007babbfe571caf1a047b808d2c7bf3e01e3084c7ebc67a491bb3699052c6534 # RoundActions
  0x024232d93f567ee49ed7e7f186b060877012f4caff1cd69bf84b8c3186254f91 # RoundViews
  0x0716b9541dfeb1cf20952062ada1d417f8d41375e980e573e7873692525adb1d # HideActions
  0x03cc8a2a12d584d79dce60ae24b545ff84cc11ed1609f623aee6887000cf489e # HideViews
  0x06f5777735e21219846dab8d822a24971e193ed39bdd233ba4ca0be1824701df # FinderValidation
  0x017e6b72aa8cb9d311001cca0952371378ad7ed1a6f4f5cb15bfe201511929b4 # FinderActions
  0x061a3f4ec8f6402fba2f90673a886ae60489dbbe8b9f009280cb697f22718405 # FinderViews
  0x01ecac72c39ccb7583d066efd4eefa45ba0fca0d79a22c615bc6c162eb26bf29 # UsdcClaims
  0x05d52ab6c6d8054a40e5bad19a0d97747bf0867ea757a4b223c7d63d73a47e0a # RozClaims
  0x016e04a316028511c6c37f8a1ea738e55dbff1b817fe7e6d6bf215a1530422df # SettingsActions
  0x00d287a5c994d04d14e450066c0e7a0eead70deb80de3832d5ec681b5035d38f # SettingsViews
  0x00060888e5f10ad35c719a9c9ab6d32f7937568f678f824f7d641fad246ea152 # Treasury
  0x036f4b18dc52af7edec3f8187513ca1475af4b5845ce8496946d572f2f4f222d # AdminUpgrade
  0x0609086696cddca40e66aad9752c106addbeb45c3f6843ab9010a877f1e68af7 # AdminActions
)

usage() {
  cat <<'USAGE'
Usage: bash scripts/deploy-routed-game.sh [--network sepolia|mainnet]
       [--doppler-config NAME] [--dry-run|--send]

Defaults to a Sepolia dry-run using Doppler config dev. Mainnet requires an
explicit --doppler-config. --send submits a fee-bearing deployment transaction;
without it, no transaction is sent. All 15 classes must already be declared on
the selected network. The RPC, account and constructor values come from Varlock.
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
if ((${#FACET_HASHES[@]} != 14)); then
  printf 'Expected exactly 14 facet class hashes.\n' >&2
  exit 2
fi

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"
printf 'Routed game %s on %s using Doppler config %s.\n' \
  "$([[ "$mode" == dry ]] && printf 'dry-run' || printf 'deployment')" \
  "$network" "$doppler_config"

# Expand constructor values only inside Varlock's child process. The private
# signing key remains in the local sncast account store, never in Doppler.
DOPPLER_CONFIG="$doppler_config" npm exec -- varlock run -- bash -c '
  set -euo pipefail
  network=$1
  config=$2
  mode=$3
  game_hash=$4
  shift 4

  node scripts/preflight-routed-game-deploy.mjs "$network" "$config" "$game_hash" "$@"

  flags=()
  if [[ "$mode" == dry ]]; then
    flags=(--dry-run --detailed)
  else
    flags=(--wait --wait-timeout 600)
  fi
  sncast --account "$SNCAST_ACCOUNT" "${flags[@]}" deploy \
    --url "$STARKNET_RPC_URL" --class-hash "$game_hash" \
    --constructor-calldata \
      "$VRF_PROVIDER_ADDRESS" "$USDC_TOKEN_ADDRESS" "$ROZ_TOKEN_ADDRESS" \
      "$ROUND_KEEPER_ADDRESS" "$ADMIN_ADDRESS" "$PAUSER_ADDRESS" \
      "$UPGRADE_DELAY" "$#" "$@"
' _ "$network" "$doppler_config" "$mode" "$GAME_CLASS_HASH" "${FACET_HASHES[@]}"
