#!/usr/bin/env bash
set -euo pipefail

# Shared by declare-routed-classes.sh and deploy-reward-token.sh. Run inside
# `varlock run` so SNCAST_ACCOUNT, STARKNET_NETWORK and STARKNET_RPC_URL come from
# Doppler. Usage: declare-classes.sh dry|send CLASS...
#
# Classes already declared at latest are skipped. Progress goes to stderr; stdout
# gets one "CLASS HASH declared|pending" line per class, where pending means a
# dry-run class that still needs a --send. sncast output is also appended to
# FEE_LOG, when set, for sum-fees.mjs.
mode=${1:?usage: declare-classes.sh dry|send CLASS...}
shift
case "$mode" in
  dry|send) ;;
  *) printf 'Mode must be dry or send.\n' >&2; exit 2 ;;
esac
(($#)) || { printf 'No classes given.\n' >&2; exit 2; }
: "${SNCAST_ACCOUNT:?SNCAST_ACCOUNT must be loaded through Varlock}"
: "${STARKNET_RPC_URL:?STARKNET_RPC_URL must be loaded through Varlock}"
: "${STARKNET_NETWORK:?STARKNET_NETWORK must be loaded through Varlock}"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

for class in "$@"; do
  printf '\n== %s\n' "$class" >&2
  artifact="target/release/project_name_${class}.contract_class.json"
  if ! hash_output=$(sncast utils class-hash --sierra-file "$artifact" 2>&1); then
    printf '%s\n' "$hash_output" | tail -n 30 >&2
    printf 'Could not hash %s; run scarb --release build first.\n' "$class" >&2
    exit 1
  fi
  local_hash=$(printf '%s\n' "$hash_output" | sed -nE 's/^Class Hash: (0x[[:xdigit:]]+)$/\1/p')
  if [[ -z "$local_hash" ]]; then
    printf '%s\n' "$hash_output" | tail -n 30 >&2
    printf 'sncast printed no class hash for %s.\n' "$class" >&2
    exit 1
  fi

  status=0
  node "$script_dir/check-declaration.mjs" "$local_hash" --status >&2 || status=$?
  if ((status == 0)); then
    printf 'Already declared on %s: %s (%s)\n' "$STARKNET_NETWORK" "$class" "$local_hash" >&2
    printf '%s %s declared\n' "$class" "$local_hash"
    continue
  fi
  if ((status != 3)); then
    printf 'Could not look up %s on %s; nothing was declared.\n' "$class" "$STARKNET_NETWORK" >&2
    exit 1
  fi

  if [[ "$mode" == dry ]]; then
    sncast --account "$SNCAST_ACCOUNT" declare --dry-run --detailed \
      --contract-name "$class" --url "$STARKNET_RPC_URL" 2>&1 | tee -a "${FEE_LOG:-/dev/null}" >&2
    printf '%s %s pending\n' "$class" "$local_hash"
    continue
  fi

  sncast --account "$SNCAST_ACCOUNT" --wait --wait-timeout 600 declare \
    --contract-name "$class" --url "$STARKNET_RPC_URL" 2>&1 | tee -a "${FEE_LOG:-/dev/null}" >&2
  # sncast rebuilds before declaring; confirm the class that landed is this build.
  if ! node "$script_dir/check-declaration.mjs" "$local_hash" --require-declared >&2; then
    printf '%s was submitted but %s is not at %s latest. Check the transaction before retrying.\n' \
      "$class" "$local_hash" "$STARKNET_NETWORK" >&2
    exit 1
  fi
  printf '%s %s declared\n' "$class" "$local_hash"
done
