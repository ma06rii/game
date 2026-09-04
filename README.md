# Realm of Zee treasure game contract

Cairo/Starknet contract for the Realm of Zee treasure hunt. Treasures hidden
during round `N` are staged for round `N + 1`; the contract is the source of
truth for that staged count and value.

## Round lifecycle

The contract starts with an empty round 0. Live play functions derive the
current round internally and accept no round id. Movement, spawning, and finds
are available only while the round is `OPEN` and before its scheduled end.
Hides stage the next round, so they remain available while the current round is
`ENDING`.

Round 0 is a deployment bootstrap: it is allowed to remain open while Week 1
hides are staged. The keeper's normal one-time expiry moves it to `ENDING`
after its timer. Round 1 opens after the buffer only when at least two treasures
have been staged; otherwise the contract waits in `ENDING` and accepts more
hides. No later round can open empty or with only one treasure.

- `hide_treasure` / `hide_treasure_bulk` stage next-round treasures.
- `finder_player_generate_position` and `finder_player_move_position` operate
  only on the current open round.
- A successful keeper validation emits `TreasureFound` with the hop delta and
  can end a non-empty round after its minimum duration when active count reaches
  zero.
- `expire_round(expectedRound)` is keeper-only. A stale expected round is a
  harmless no-op; time expiry is accepted after the 60-second validation grace.
- `start_next_round(params)` is keeper-only, requires `ENDING` plus the stored
  end buffer and at least two staged treasures, checks the supplied expected
  count/value against staged contract facts, and increments the round
  internally.

`start_next_round` writes only the new round configuration. It never overwrites
`total_reward_shares_for_hiders` or `game_totals`; those slots were already
populated by real hides. This is the regression protected by
`test_start_next_round_preserves_the_live_staged_count`.

## Configuration and accounting

Each new round snapshots its stake, hide fees, tiered hop prices, spawn fee,
grid, Merkle root and timing. Fee ceilings and timing relationships are checked
on-chain. The hider's eventual net USDC claim value is snapshotted when the
stake is charged, so later fee changes cannot reprice an old claim.

The fourth constructor argument is the dedicated round keeper address. The
owner can rotate it with `update_round_keeper`; lifecycle calls are not exposed
to ordinary players.

## Events used off-chain

- `TreasureHidden` feeds coordinate staging.
- `CheckForTreasure` feeds keeper validation and includes the player's current
  round hop count.
- `TreasureFound` records successful-find hop deltas for density control.
- `RoundStarted` records official round fees, timing, grid and active count.
- `RoundEnded` records the end reason and found/surviving counts.

After every deployment, derive the event selectors from the built ABI and
update the dev indexer configuration together with the contract address and
deployment block.

## Development

```bash
scarb build
scarb test
```

The contract uses USDC-style 6-decimal gameplay amounts and a separate
18-decimal ROZ reward token. Current deployed addresses in `new_addresses.txt`
describe the previous deployment until a new coordinated deployment replaces
them.
