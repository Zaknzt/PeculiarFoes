# PeculiarFoes

PeculiarFoes is a Windower 4 addon for Final Fantasy XI that tracks the 15 monthly **Peculiar Foes** Records of Eminence objectives in a compact draggable HUD and shows an explicit travel route to the next unfinished foe.

## Features

- Displays Peculiar Foes I-XV in order.
- Green `[ ]` = active and unfinished this month.
- Grey `[x]` = completed this month.
- Amber `[!]` = not currently active and not known complete.
- Amber `[?]` = active RoE state is still loading.
- Keeps the route footer on the earliest unfinished objective even if later foes are completed first.
- Shows an Elijah reminder after all 15 are complete.
- Persists monthly completion state across addon reloads and zone changes.
- Clears saved monthly completion state at the start of a new Japanese calendar month.
- Includes explicit warp-first travel directions for every foe.

## Safety / scope

PeculiarFoes does **not** automate movement, targeting, combat, footprint interaction, or objective changes.

The addon reads the normal active/progress RoE packet (`0x111`). Its only outgoing packet is the standard RoE-log refresh request (`0x112`) used when refreshing objective state.

## Requirements

- Windower 4
- Windower libraries: `packets`, `texts`, and `config`

## Install

1. Create `Windower4/addons/PeculiarFoes/` if it does not already exist.
2. Copy `PeculiarFoes.lua` into that folder.
3. In game, run:

   `//lua load PeculiarFoes`

If the addon is already loaded after updating the file, use:

`//lua reload PeculiarFoes`

## Commands

- `//pfoes` or `//pfoes status` — show compact status in chat
- `//pfoes show` — show the HUD
- `//pfoes hide` — hide the HUD
- `//pfoes toggle` — toggle the HUD
- `//pfoes refresh` — request fresh active RoE state
- `//pfoes done I XV` — manually mark one or more objectives complete this month
- `//pfoes undo I XV` — manually mark one or more objectives unfinished this month
- `//pfoes done all` / `//pfoes undo all`
- `//pfoes reset` — clear saved monthly state and re-read active RoEs
- `//pfoes pos <x> <y>` — move and save the HUD position
- `//pfoes pos reset` — restore the default position
- `//pfoes pos status` — print the current position
- `//pfoes help` — show command help

## First-run note

PeculiarFoes determines current-month completion from the active Peculiar Foes RoE list plus its own saved monthly state. The game also exposes lifetime completion flags for repeatable objectives; those are intentionally **not** treated as current-month completion authority.

For the cleanest first reconciliation, activate the full Peculiar Foes I-XV sequence before first loading the addon. If only a hand-selected subset was active, an absent objective may initially be inferred as completed this month. Correct any such entry with `//pfoes undo <roman numeral>`, or use `//pfoes reset` after activating the intended sequence.

## Route III note

Peculiar Foes III uses the Aht Urhgan / Nyzul / Hediva route rather than the Captain-gated Unity 135 teleport. The HUD route begins at **Aht Urhgan Whitegate #2**, proceeds through the Chamber of Passage and Runic Portal to Nyzul Isle Staging Point, then through the Undersea Ruins to Hediva Isle and the I-6 footprints.

## Known limitations

- Initial monthly reconciliation is based on the active RoE sequence. A deliberately incomplete active set may need a manual `undo` correction as described above.
- Route text reflects the travel paths encoded in this release; game updates can make travel guidance stale even when objective tracking still works.
- PeculiarFoes tracks the monthly checklist locally. It does not claim that lifetime RoE completion flags represent current-month completion.

## Version

Current public release candidate: **v0.1.5**.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
