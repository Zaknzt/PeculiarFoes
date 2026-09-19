# Changelog

## v0.1.5

- Replaced the Peculiar Foes III Unity 135 route with the Aht Urhgan Whitegate #2 -> Nyzul Isle -> Hediva Isle route so the instructions do not depend on the Captain-gated Unity destination.

## v0.1.4

- Replaced dynamically added completion-setting keys with a predefined numeric completion mask for reliable persistence across reloads and zone changes.
- Added first-snapshot reconciliation so saved state can recover correctly after reload.

## v0.1.3

- Expanded every route so it begins with the actual travel action and named warp destination rather than shorthand arrival-zone text.
- Added deliberate line breaks to keep longer HUD routes readable.

## v0.1.2

- Stopped treating the incoming `0x112` lifetime-completion bitmap as current-month completion authority for repeatable Peculiar Foes objectives.
- Switched monthly state reconciliation to the active `0x111` RoE list plus locally persisted monthly completion state.
- Added manual `done`, `undo`, and `reset` correction controls.
