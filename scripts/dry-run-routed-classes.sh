#!/usr/bin/env bash
set -euo pipefail

# Read-only estimates for every class needed by one routed deployment. A
# successful dry-run is not an accepted declaration and sends no transaction.
: "${SNCAST_ACCOUNT:?Set SNCAST_ACCOUNT to the configured Sepolia account alias}"

classes=(
  GameRoundActionsFacet GameRoundViewsFacet
  GameHideActionsFacet GameHideViewsFacet
  GameFinderValidationFacet GameFinderActionsFacet GameFinderViewsFacet
  GameUsdcClaimsFacet GameRozClaimsFacet
  GameSettingsActionsFacet GameSettingsViewsFacet
  GameTreasuryFacet GameAdminUpgradeFacet GameAdminActionsFacet
  HelloStarknet
)

for class in "${classes[@]}"; do
  printf '\n%s\n' "$class"
  if output=$(sncast --account "$SNCAST_ACCOUNT" declare \
    --contract-name "$class" --network sepolia --dry-run --detailed 2>&1); then
    summary_lines=()
    saw_success=false
    saw_l2_gas=false
    saw_fee=false
    while IFS= read -r line; do
      case "$line" in
        Success:*) saw_success=true; summary_lines+=("$line") ;;
        L2\ Gas\ Consumed:*) saw_l2_gas=true; summary_lines+=("$line") ;;
        Overall\ Fee:*) saw_fee=true; summary_lines+=("$line") ;;
        Transaction\ hash:*) summary_lines+=("$line") ;;
      esac
    done <<< "$output"
    if [[ "$saw_success" != true || "$saw_l2_gas" != true || "$saw_fee" != true ]]; then
      printf '%s\n' "$output" | tail -n 30 >&2
      printf 'Dry-run output for %s lacked a success line, L2 gas, or fee estimate.\n' \
        "$class" >&2
      exit 1
    fi
    printf '%s\n' "${summary_lines[@]}"
  else
    declared_hash=$(printf '%s\n' "$output" | sed -nE \
      's/^Error: Failed to estimate fee for dry run: .*Class with hash (0x[[:xdigit:]]+) is already declared\..*$/\1/p')
    if [[ -n "$declared_hash" ]]; then
      artifact="target/release/project_name_${class}.contract_class.json"
      if [[ ! -f "$artifact" ]]; then
        printf 'Missing release artifact for %s; run scarb --release build first.\n' "$class" >&2
        exit 1
      fi
      if ! hash_output=$(sncast utils class-hash --sierra-file "$artifact" 2>&1); then
        printf '%s\n' "$hash_output" | tail -n 30 >&2
        printf 'Could not calculate the local class hash for %s.\n' "$class" >&2
        exit 1
      fi
      local_hash=$(printf '%s\n' "$hash_output" | sed -nE 's/^Class Hash: (0x[[:xdigit:]]+)$/\1/p')
      if [[ -z "$local_hash" || "${declared_hash,,}" != "${local_hash,,}" ]]; then
        printf 'Already-declared hash %s does not match local release hash %s for %s.\n' \
          "$declared_hash" "${local_hash:-unavailable}" "$class" >&2
        exit 1
      fi
      if ! check_output=$(DOPPLER_CONFIG=dev npm exec -- varlock run -- \
        node scripts/check-declaration.mjs "$local_hash" --require-declared 2>&1); then
        printf '%s\n' "$check_output" | tail -n 30 >&2
        printf 'Could not confirm %s at Sepolia latest; reconcile providers before continuing.\n' \
          "$class" >&2
        exit 1
      fi
      printf 'Already declared at Sepolia latest: %s (%s); no new fee estimate.\n' \
        "$class" "$local_hash"
      continue
    fi
    printf '%s\n' "$output" | tail -n 30
    printf 'Dry-run failed for %s; no declaration was submitted.\n' "$class" >&2
    exit 1
  fi
done
