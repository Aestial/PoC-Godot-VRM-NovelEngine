# TPS Shooter Demo — Implementation Plan

Status: **Approved for planning** (decisions locked 2026-06, session analysis).
Goal: a fun, playable third-person-shooter demo built **on the Modular Character Controller (MCC) framework** (vendored addon `addons/character_controller`, pinned byte-identical to upstream `af45779d61f88bc48848be92a2598bc94010be1f`) and extending the project's existing character features (VRM avatars, Dialogic 3D interactions, MCC actions/controllers) — not replacing them.

---

## 0. Locked decisions (chosen by project owner)

| # | Decision | Choice |
|---|---|---|
| D1 | Venue | New standalone arena scene + scripts under `samples/shooter_demo/` |
| D2 | Fire model | **Hitscan + tracer visuals** (architecture leaves room for projectiles later) |
| D3 | Feel scope | Solid lean TPS kit: ADS zoom, recoil/spread, reload + ammo, crosshair, hitmarkers, impact/muzzle FX |
| D4 | Targets | Static + moving target props and destructible props in v1; **hostile bots guaranteed as next phase** |
| D5 | Weapon visuals | Stylized CC0/CSG gun attached to a hand/chest socket; **no new animation assets in v1**; feel comes from body-turn, camera kick, FX |
| D6 | VN coexistence | Player remains the current VRM `NovelCharacter`-style third-person character; a talkable NPC with a short Dialogic timeline sits next to the range; firing is blocked while Dialogic is active |

Hard rules:

- **Never edit `addons/character_controller/`** (upstream core, re-vendor-able). Extend via the framework's own seams: `ActionNode` subclasses, `Controller` subclasses, `MovementState` behavior.
- Never edit `addons/vrm`, `addons/dialogic`, `addons/phantom_camera`, `addons/signal_lens` (third-party).
- All gameplay code lives in `samples/shooter_demo/`; small additive hooks may touch `visual-novel/scripts/*` only where strictly needed and backward-compatible.
- Do not disturb the uncommitted WIP in the working tree (`project.godot` autoload/plugin wiring, `_scenario_prototype.tscn`, `_scenario_testground.tscn`).

---

## 1. Baseline facts the plan builds on (analysis summary)

### 1.1 Framework (MCC @ af45779)
- Repo: `PantheraDigital/Modular-Character-Controller-for-Godot`, commit `af45779…` (2025-09-24, README-only change on `main`; no releases/tags; README is the manual).
- Core = 6 scripts (`addons/character_controller/scripts/`): `ActionNode`, `ActionContainer`, `ActionContainerConfig`, `Controller`, `MovementState`, `MovementStateManager`. All **verified byte-identical** (git hash-object vs upstream tree) to the linked commit.
- Model: character body exposes only **Actions** (public API, keyed by `ACTION_ID`, layered vs non-layered, interrupt whitelists) through an **ActionContainer**; **Controllers** (external nodes with `controlled_obj`) are the only callers; **MovementStates** own physics and are swapped by a **MovementStateManager**.
- Sample content was relocated into `samples/controller_examples/` but still references upstream paths `res://controller_examples/…` / `res://character_controller/…`; scenes load via Godot 4.4+ UID remap, but `dash_pickup_trigger.gd` does a **runtime `load()` with a dead path → Dash pickup grants nothing**.

### 1.2 Project character stack
- `NovelCharacter` (`visual-novel/scripts/character/novel_character.gd`, `extends CharacterBody3D`, group `ControllableCharacter`) = unified player/NPC template; scene `visual-novel/characters/novel_character_base.tscn`; per-character packed scenes in `visual-novel/GJDDM/characters/packed/`.
- Contains: `ActionContainer/{Move,Jump}` (custom `action_move_simple.gd`, `action_jump.gd`), `MovementManager/GroundedMovement` (`movement_grounded_complex.gd` — project fork of the sample: Behavior flags, ledge step-up/down via `CharacterStep3D`, air control, **drives AnimationTree each physics frame**), `CollisionShape3D` w/ `character_collision_shape.gd` (**model yaw-turns toward velocity**; `mesh_faces_camera_direction` export already anticipates facing the camera), `ModelContainer` (VRM instance; `AnimationPlayer` auto-wired), `ThirdPersonCamera` pivot + SpringArm3D + PhantomCamera3D (FOV presets, priority API), `PortraitCamera`, `InteractionArea3D`, `Socket`, `GazeTarget`, `InteractionHUD`, custom `AnimationTree` (`CharacterAnimationTree`: pose/locomotion/facial layers, noise blinking, Dialogic mood/viseme events).
- Controllers (`visual-novel/scripts/controllers/`): `ControllerPlayer` (+`…ThirdPerson`: camera-relative MOVE with `aim_direction` param), `ControllerAi` (+`…ThirdPerson`). Actions available as code: jump, dash, fly, move, toggle movement state (flight toggle not wired in base scene).
- Dialogic 3D: interaction area → HUD prompt → timeline start/end pauses/resumes movement; socket staging; portrait/third-person/cinematic cameras by PhantomCamera priority; custom event **Character 3D** (`addons/dialogic_additions/`) drives facial moods; voiceover audio present; viseme lip-sync is a TODO.
- World: physics layers `world`=1, `player`=2; input map: move/run/jump/dash/cam_left…/interact(X)/pause/dialogic actions; renderer forced `gl_compatibility` (web-export legacy) with physics interpolation on; main scene is the VRM viewer app; the VN runs via `Title → Welcome → Metro/Teatro → Laberinto` (`SceneLoader`, quest canvas, Dialogic vars).
- Known gaps/bugs found: RUN input has no action; DashPickup stale path; flight/toggle actions unwired in base scene; dialogue interaction lacks debounce; debug prints; hardcoded Spanish HUD text; `run` FOV preset unused; per-scene pointer-capture poll loop.

---

## 2. Target architecture

New tree (files created by this plan):

```
samples/shooter_demo/
├── scenes/
│   ├── shooter_arena.tscn        # the demo level (target bays, cover, env)
│   └── shooter_hud.tscn          # CanvasLayer UI (crosshair/ammo/score/…)  [instanced by arena]
├── scripts/
│   ├── controller_player_shooter.gd   # extends ControllerPlayerThirdPerson
│   ├── shooter_character.gd           # extends NovelCharacter (combat state, aiming face-turn)
│   ├── shooter_character.tscn?         # (scene lives in scenes/; inherited from novel_character_base)
│   ├── weapon/
│   │   ├── weapon_rig.gd          # character-private node: weapon state machine (not an Action)
│   │   ├── action_shoot.gd        # ActionNode ACTION_ID "SHOOT" (layered? impulse, cooldown)
│   │   ├── action_aim.gd          # ActionNode ACTION_ID "AIM" (layered)
│   │   └── action_reload.gd       # ActionNode ACTION_ID "RELOAD" (non-layered w/ whitelist MOVE)
│   ├── combat/
│   │   ├── health.gd              # generic int health w/ signals (targets now, bots next phase)
│   │   └── target_dummy.gd        # static target (hit flash, score, respawn)
│   │   └── moving_target.gd       # rail/sine moving target (D4)
│   │   └── destructible_prop.gd   # crate/barrel that breaks (D4)
│   ├── fx/
│   │   ├── tracer.gd              # line3D fade-out tracer
│   │   └── impact_fx.gd           # spark decal/particles at hit point
│   └── ui/
│       ├── shooter_hud.gd         # crosshair spread, ammo, score, hitmarker, damage popups
│       └── score_keeper.gd        # level-side scoring/timer
├── characters/
│   └── shooter_player.tscn        # inherited from novel_character_base + WeaponRig + new Actions
├── npc/
│   └── range_npc.tscn             # inherited NPC (NovelCharacter) with intro timeline (D6)
└── dialogic/
    └── shooter_intro.dtl          # short range-intro timeline (+ project.godot dtl_directory entry)
```

Framework mapping (what plays which role in MCC terms):

| MCC concept | Shooter usage |
|---|---|
| `ActionNode` | `SHOOT`/`AIM`/`RELOAD` on the character's `ActionContainer`; they call character-private `WeaponRig` |
| `ActionContainer` | unchanged; new children added in `shooter_player.tscn` |
| `Controller` | `ControllerPlayerShooter` (extends project's `…ThirdPerson`): trigger, ADS hold, reload, respects Dialogic `is_busy`, mouse capture |
| `MovementState` | unchanged (`MovementGroundedComplex`); ADS speed handling via exported move-speed modulation (new optional layered RUN-style approach) |
| Internal nodes | `WeaponRig` (private), `Health`, HUD, targets — reachable only through actions or signals |

Core loop (framework-conformant):
1. `ControllerPlayerShooter` polls: if LMB held && !`Dialogic.current_timeline` → `play_action("SHOOT", {…})` each frame; `ActionShoot.can_play()` enforces fire rate / ammo / reload state (single clock, mirrors `action_dash.gd` cooldown pattern).
2. `ActionShoot.play()` → `WeaponRig.fire()`: computes aim ray from the **current viewport camera center** (fixed crosshair), applies spread, raycasts mask = world(1) | shootable targets (new layer), damages `Health` in group `ShootableTargets`, spawns tracer + impact FX, triggers muzzle flash, camera kick, HUD events, animation-tree "fire" cue (small pose/arms impulse only if a seam exists; else FX only — D5).
3. `AIM` (layered, while RMB): `WeaponRig`/camera enter ADS — FOV lerp toward 35–40°, optional spring-arm shorten; `ShooterCharacter` sets the collision-shape flag to face the camera (body-turn seam in `character_collision_shape.gd`: runtime setter of `mesh_faces_camera_direction`, additive change to the project script).
4. `RELOAD` (non-layered, whitelist `MOVE`): plays on R/auto at empty; interrupts firing; ammo restored after `reload_time`.
5. Everything else (walk/jump/dash, VRM blink/moods, interactions) keeps working untouched; dialogue blocks 2–4 via the existing `is_busy`/`Dialogic.current_timeline` checks.

Collision/layer changes (project settings, additive):
- New physics layer `shootable` (=4): static/moving targets and destructible props. Raycast mask `world | shootable`, `collide_with_areas = true` for Area-based targets.
- Targets: popup/paper targets = `Area3D`/`StaticBody3D` on `shootable` only (never block player, layer excluded from player mask); destructible props = `StaticBody3D` on `world | shootable` so the player collides with them (solid crates that can be destroyed); group `ShootableTargets`.
- NPC bystander: existing `ControllableCharacter` group on `player`-layer body is **explicitly excluded** from the damage ray (group check) — safe-by-construction (D6).

---

## 3. Phases

### Phase 0 — Baseline hardening (small, high-value fixes before feature work)
- [x] Fixed `DashPickup` + all stale sample refs (`res://controller_examples/…`, `res://character_controller/…` → relocated `samples/`/`addons/` paths); the runtime `load()` in `dash_pickup_trigger.gd` now resolves and the grant was verified end-to-end (headless smoke PASS). Dash is kept; wiring into the shooter container happens in Phase 1.
- [x] RUN decision: implemented layered `action_run.gd` (`samples/shooter_demo/scripts/actions/`, ACTION_ID `RUN`, grounded-only, exported `run_speed`); node wiring into the shooter character happens in Phase 1. Existing input action `run` (Shift) already drives play/stop via the controller.
- [x] Input map: added `fire` (LMB), `aim` (RMB), `reload` (R) — verified registered (1 event each); no clash with `dialogic_default_action` / pointer capture; `interact` (X) untouched. Gamepad bindings deferred to a later pass.
- [ ] Pointer/pause discipline: pattern confirmed in existing code; final capture-on-start wiring lands with the arena scene in Phase 3.
- [x] Added `shootable` physics layer name (3d_physics/layer_3) for targets in Phase 2.
- **Acceptance:** ✅ all touched scenes boot clean headless (testground, MCC Prototype, Welcome) with zero script/scene errors; no stale path references remain (grep = 0).

**Phase 0 close-out notes (session log):**
- Renderer upgraded: `renderer/rendering_method="forward_plus"` (Windows-only target; `.mobile` left as `gl_compatibility`). Requires one editor open/import pass to refresh caches — spot-check visuals in-editor.
- `visual-novel/animations/rifle-shooting-mvc.res` verified loadable (binary resource). Clips (55 tracks each): `Rifle Idle`, `Rifle Aiming Idle`, `Rifle Run`, `Walking`, `Gunplay` (0.47 s), `Firing Rifle` (2.37 s), `Reload` (8.2 s), `Reloading` (6.8 s), `X Bot`. These are for Phase 1: load as a new animation library on the player model and drive via a dedicated rifle blend/pose layer.
- Validated with Godot v4.6.3 (Godots) headless; harnesses were temporary (under `.godot/`, removed).

### Phase 1 — Combat core (D2, D3, D5)
- [x] `weapon_rig.gd` (`samples/shooter_demo/scripts/weapon/`) + `weapon_config.gd` resource: damage, fire_rate, auto/semi, mag/reserve, reload_time, spread + bloom, recoil, range, tracer color; single data-driven rifle for v1. Rig is character-private ("body"); actions are the public API.
- [x] Actions `SHOOT` (impulse, cooldown in rig) / `AIM` (layered) / `RELOAD` (non-layered, whitelists MOVE/AIM/RUN); controller `ControllerPlayerShooter` (LMB auto/semi + edge detect, RMB ADS, R reload, auto-reload on empty trigger, dry-fire click). All combat gated by `NovelCharacter.is_busy` (no firing during Dialogic).
- [x] ADS & camera: additive, back-compatible additions to `third_person_camera.gd` — `set_aim_active()` (smooth FOV + spring-arm blend) and `add_recoil()` (decaying view kick).
- [x] Body-turn while aiming/firing: `WeaponRig` drives the existing `mesh_faces_camera_direction` flag on `character_collision_shape.gd` (no script change needed there).
- [x] Gun visuals: stylized CSG rifle (`weapons/rifle_placeholder.tscn`, replaceable via `WeaponRig.gun_scene`) mounted on the rig under `CollisionShape3D` with a Muzzle marker. Hand-bone/socket polish deferred with the animation layer.
- [x] HUD v1 (`scenes/shooter_hud.tscn` + `ui/` scripts): crosshair with live spread (grows with bloom), ammo `mag / reserve`, reloading + "Press R" prompts, low-ammo color, hitmarker flash (fires on `WeaponRig.target_hit`).
- [x] Muzzle flash (`OmniLight3D` pulse) + tracer (fading additive box beam) + impact flash FX via `fx/fx_bank.gd`.
- [x] SFX: procedural PCM placeholders via `audio/sfx_bank.gd` (shot/dry/reload/hit) — no assets; swappable later.
- [x] Dev level: `scenes/shooter_range.tscn` (Natalia `shooter_player.tscn` + plank wall gallery) — boot scene for testing.
- **Acceptance:** ✅ headless combat harness PASS (26 checks: mag 30/120, cadence & cooldown, ADS zoom + body turn + tightened spread, fire-in-ADS, reload refill 30/90, busy gating, no errors in fire path w/ tracer/impact FX). ✅ range/testground/Welcome/Prototype boot clean. Visual feel (crosshair, tracer look, ADS smoothness, gun placement on Natalia's hands) needs one in-editor pass by the owner.

**Phase 1 close-out notes:**
- Rendering note: previous "GL-compatibility" bullet is obsolete — project runs Forward+ now (Phase 0), so the arena can use standard forward materials; keep FX lightweight anyway (tracers are pooling candidates later).
- Rifle animation layer (rifle-shooting-mvc clips) deliberately deferred (D5 decision); `WeaponRig` emits signals (`shot_fired`, `aim_changed`, `reload_finished`) ready to drive it in the polish pass.
- Rig muzzle/hand placement (`WeaponRig` at `CollisionShape3D` local ≈ (0.14, 0.85, 0.02)) is a first guess — adjust in-editor to Natalia's right hand pose.

### Phase 2 — Targets & damage (D4 part 1)
- [ ] `health.gd` (signals: damaged, died, respawned) + `target_dummy.gd` (hit flash, knockdown tween, score, timed respawn; popup + fixed variants), `moving_target.gd` (simple rail back-and-forth), `destructible_prop.gd` (crates; gibbed into debris or simple hide+respawn).
- [ ] `score_keeper.gd`: score/time/accuracy; end-of-run banner + restart (R on results or arena respawn button) reusing pause/restart patterns from GJDDM.
- [ ] Damage popups & hitmarker states (hit/kill), headshot-style bonus via target zones if cheap.
- **Acceptance:** shooting gallery flow: 60–90 s run, moving + static targets score points, props break, score persists across respawns, restart clean.

### Phase 3 — Arena level, VN coexistence & fun pass (D1, D6)
- [ ] `shooter_arena.tscn`: gallery with firing lanes/backstops from existing assets (`kenney_prototype_textures`, sample color textures, corridor GLBs as side dressing), cover props, spawn layout, lighting/environment copied from `_scenario_testground.tscn` patterns (sky, shadows; GL-compatible).
- [ ] `shooter_intro.dtl` + NPC bystander near entrance w/ interaction hint (existing InteractionHUD path), NPC standing outside lanes + explicit non-damage guarantee; also validates D6 (movement freeze + camera focus during talk still work with weapon rig).
- [ ] Difficulty pacing: target speed/activation randomness, score tiers (Bronze/Silver/Gold) for replayability.
- [ ] Boot: run `shooter_arena.tscn` directly for dev; optional Title entry button later (out of scope unless wanted).
- **Acceptance:** one scene boots the whole demo; talks with NPC mid-arena are safe; run is fun & replayable; no regressions in existing chapters (spot-run testground/Metro).

### Phase 4 — Hostile bots (D4 part 2, guaranteed next phase)
- [ ] Enemy controller (extends `ControllerAiThirdPerson`): states patrol → spot player → chase/strafing → attack (attack via same `SHOOT`-style action + hitscan w/ accuracy falloff by distance) reusing `Health`.
- [ ] Player `Health` + damage feedback (screen flash) + respawn at arena start with score penalty.
- [ ] Simple bot visual (CSG/primitive v1; NovelCharacter/VRM variant optional later) + spawn points; difficulty ramp.
- **Acceptance:** bots that threaten the player, die to hitscan, respawn; arena becomes a horde-mode variant accessible from the gallery.

---

## 4. Risks & notes
- **Renderer** is now **Forward+** (desktop/Windows target; `.mobile` stays compatibility for future web exports). Keep FX lightweight anyway — tracers/impacts are per-shot node spawns and should be pooled if the arena gets busy.
- **VRM animation**: no gun animations exist; v1 relies on existing pose/locomotion + body-turn; do not retarget Mixamo combat clips into VRM libraries in v1 (D5) — reassess in Phase 4.
- **Turn-to-aim mechanics** depend on additive hooks in `character_collision_shape.gd` (project code, safe to extend; keep default behavior for existing scenes: flag defaults preserve velocity-facing).
- **Dialogic interplay**: `NovelCharacter.is_busy`/`Dialogic.current_timeline` gates all combat input; verify socket teleport does not desync weapon rig (rig lives under CollisionShape3D, rotates with model).
- **`.dtl` authoring** for the intro timeline is done by hand-mimicking an existing `.dtl` + registering the directory entry in `project.godot`; validate in-editor.
- Keep commits staged per phase with the arena runnable at each phase end.

## 5. Out of scope (unless requested)
- Lip-sync/visemes, weapon animation imports, arsenal switching, save/load, leaderboards, online/web export of the arena (only desktop dev runs in v1).
