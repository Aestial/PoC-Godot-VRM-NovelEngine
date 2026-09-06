# TPS Shooter Demo — Animation Requirements & Asset Checklist

This document specifies the required animations for the **TPS Shooter Demo** outlined in [`docs/shooter_demo_plan.md`](file:///home/dorito/Developer/Godot-Projects/FrutigerHorror/docs/shooter_demo_plan.md). It serves as a definitive acquisition guide for Mixamo and itch.io animation packs, defining expected naming conventions, visual postures, and an actionable checklist for subsequent agents to build the animation library.

---

## 1. Technical Guidelines for Sourcing & Importing

### 1.1 Mixamo Download Settings
When downloading from [Mixamo](https://www.mixamo.com/):
- **Character**: Download using a standard humanoid reference (e.g., **Y Bot** or **X Bot**).
- **Format**: `FBX for Unity (.fbx)` or standard `FBX (.fbx)`.
- **Skin**: 
  - If downloading single clips: Choose **Without Skin** (smaller files).
  - If importing as reference: Download one T-Pose / Base with skin.
- **Frames Per Second (FPS)**: **60 FPS** (or consistent 30 FPS; 60 FPS recommended for smooth shooter blend trees).
- **Keyframe Reduction**: **None** (preserves weapon alignment and hand positioning).
- **In Place Checkbox (CRITICAL)**:
  - **Always check "In Place"** for all locomotion clips (Walk, Run, Strafe, Roll/Dash, Jump).
  - Godot's MCC (`MovementGroundedComplex`) and `CharacterBody3D` handle translation physics. Animations with root motion will cause model desynchronization from the collision capsule.

### 1.2 Itch.io / Indie Pack Conventions
When using packs from itch.io (e.g., Kevin Iglesias, Synty, Kay Lousberg, Quaternius):
- Always pick the **In-Place** variant if the pack separates root motion and in-place animations.
- Prefer **Rifle / Two-Handed Carbine** packs to match the Phase 1 weapon specification.
- Ensure the skeleton matches standard humanoid proportions (compatible with Godot's Humanoid bone mapper).

### 1.3 Godot 4 & VRM Retargeting Architecture
- In Godot 4, imported FBX/GLTF animations are retargeted to the VRM avatar using Godot’s **`HumanoidBoneMap`** (configured on `GeneralSkeleton`).
- Upper-body layering: Combat actions (aiming, shooting, reloading) will be layered onto the MCC locomotion state machine via bone filters (filtering from `Spine` / `Chest` upwards), allowing simultaneous movement and firing.

---

## 2. Animation Catalog & Visual Descriptions

### Category A: Locomotion & Agility (Phase 0 & Base Movement)

| # | Action / Role | Probable Mixamo Name | Probable itch.io Name | Visual Description & Posture |
|---|---|---|---|---|
| A1 | **Combat Idle (Low Ready)** | `Rifle Idle` | `Rifle_Idle` / `Rifle_CombatIdle` | Character stands alert, legs shoulder-width apart, knees slightly bent. Holding rifle across chest/hip at a 45-degree angle downward ("low ready"). Breathing motion. |
| A2 | **Combat Walk Forward** | `Rifle Walk` / `Walking With Rifle` | `Rifle_Walk_Fwd` / `Walk_Rifle_Fwd` | Confident forward stride holding rifle with both hands across the chest. Eyes forward. In-place loop. |
| A3 | **Combat Walk Backward** | `Rifle Walk Backwards` / `Walking Backwards` | `Rifle_Walk_Bwd` / `Walk_Rifle_Bwd` | Careful backward stepping while keeping torso upright and weapon pointed forward/ready. |
| A4 | **Combat Strafe Left** | `Rifle Strafe Left` / `Left Strafe Walk With Rifle` | `Rifle_Strafe_Left` / `Walk_Strafe_L` | Sidestepping left while keeping upper body facing front, weapon ready. |
| A5 | **Combat Strafe Right** | `Rifle Strafe Right` / `Right Strafe Walk With Rifle` | `Rifle_Strafe_Right` / `Walk_Strafe_R` | Sidestepping right while keeping upper body facing front, weapon ready. |
| A6 | **Combat Sprint / Run** | `Rifle Run` / `Run With Rifle` | `Rifle_Run` / `Rifle_Sprint` | Fast, aggressive forward sprint. Right hand holds grip, left hand supports handguard or pumps slightly, weapon lowered slightly for speed. In-place. |
| A7 | **Jump - Start / Upward** | `Standing Jump` / `Rifle Jump` | `Rifle_Jump_Start` / `Jump_Takeoff` | Compression/crouch anticipation and explosive upward push. |
| A8 | **Jump - Mid-Air / Falling** | `Falling Idle` / `Fall` | `Rifle_Jump_Air` / `Jump_Fall_Loop` | Character in mid-air holding rifle, legs extended slightly downward. Looping air time. |
| A9 | **Jump - Landing** | `Landing` / `Hard Landing` | `Rifle_Jump_Land` / `Jump_Land` | Knee bend absorbing impact on ground contact, quickly recovering to combat stance. |
| A10 | **Dash / Combat Roll** | `Standing Dive Roll` / `Forward Roll` / `Sprint Forward Roll` | `Rifle_Dodge_Roll` / `Combat_Roll_Fwd` | Quick forward dive and roll or low evasive slide, recovering back to feet. Triggered by MCC Dash action. |

---

### Category B: Aiming & Weapon Handling (Phase 1 Combat Core)

| # | Action / Role | Probable Mixamo Name | Probable itch.io Name | Visual Description & Posture |
|---|---|---|---|---|
| B1 | **Aim Down Sights (ADS) Idle** | `Rifle Aiming Idle` / `Aiming Idle` | `Rifle_Aim_Idle` / `ADS_Idle` | Stock pressed firmly against shoulder, cheek tilted to sight line, barrel perfectly level forward, posture tense and stable. |
| B2 | **Aim Walk Forward** | `Rifle Aiming Walk Forward` / `Aim Walk` | `Rifle_Aim_Walk_Fwd` / `ADS_Walk_Fwd` | Slow, tactical forward creep while maintaining sight alignment. Minimal bobbing. |
| B3 | **Aim Walk Backward** | `Rifle Aiming Walk Backwards` | `Rifle_Aim_Walk_Bwd` / `ADS_Walk_Bwd` | Slow backward backing up without dropping the aim line. |
| B4 | **Aim Strafe Left** | `Rifle Aiming Strafe Left` | `Rifle_Aim_Strafe_L` / `ADS_Strafe_L` | Slow lateral shuffle left while aiming down the scope/sight. |
| B5 | **Aim Strafe Right** | `Rifle Aiming Strafe Right` | `Rifle_Aim_Strafe_R` / `ADS_Strafe_R` | Slow lateral shuffle right while aiming down the scope/sight. |
| B6 | **Single Shot Recoil** | `Firing Rifle` / `Shooting` | `Rifle_Shoot` / `Rifle_Fire_Single` | Sharp, sudden backward kick into the shoulder, slight barrel muzzle flip, immediate quick return to rest. |
| B7 | **Rapid Fire / Auto Recoil** | `Rifle Rapid Fire` / `Automatic Fire` | `Rifle_Fire_Auto` / `Rifle_Burst` | Rapid rhythmic shoulder vibrations and muzzle jitter for sustained fire. |
| B8 | **Aimed Shot Recoil** | `Aiming Firing Rifle` | `Rifle_ADS_Shoot` / `ADS_Fire` | Recoil impulse executed directly from the eye-level ADS stance with minimal head displacement. |
| B9 | **Reload (Tactical / Magazine)** | `Reloading` / `Rifle Reload` | `Rifle_Reload` / `Reload_Magazine` | Left hand releases empty magazine from receiver, fetches fresh mag from hip/vest, firmly seats magazine with an audible slap, racks charging handle or bolt release. |
| B10 | **Equip / Draw Weapon** *(Optional Polish)* | `Draw Rifle` / `Equip Weapon` | `Rifle_Equip` / `Rifle_Draw` | Pulls weapon from shoulder sling/back into ready position. |

---

### Category C: Damage Reactions & Deaths (Phase 1/2 Combat & Phase 4 Bot/Player Death)

| # | Action / Role | Probable Mixamo Name | Probable itch.io Name | Visual Description & Posture |
|---|---|---|---|---|
| C1 | **Impact Flinch - Front** | `Hit To Body` / `Body Impact` | `Hit_Chest` / `Impact_Front` | Upper body jerks backward as hitscan bullet hits chest; quick recovery. Ideal for short additive blend. |
| C2 | **Impact Flinch - Head / Heavy** | `Head Hit` / `Heavy Hit Reaction` | `Hit_Heavy` / `Impact_Head` | Head knocks backward/sideways with brief stumble before regaining balance. |
| C3 | **Death - Fall Backward** | `Death From The Front` / `Standing Death Backward` | `Death_Backward` / `Death_01` | Shot from front; legs buckle, character falls straight back onto back/shoulders, limbs relaxing. |
| C4 | **Death - Fall Forward / Collapse** | `Dying` / `Fall Forward Death` | `Death_Forward` / `Death_Collapse` | Knees hit ground first, upper body drops face-down into ground. |

---

### Category D: Hostile Bots / AI Enemies (Phase 4 Horde & Target Bots)

| # | Action / Role | Probable Mixamo Name | Probable itch.io Name | Visual Description & Posture |
|---|---|---|---|---|
| D1 | **Bot Patrol Walk** | `Walking` / `Alert Patrol Walk` | `Enemy_Patrol_Walk` / `Zombie_Walk_01` | Deliberate, paced walking cycle; scanning surroundings (e.g. security patrol or creepy unnatural stride for horror theme). |
| D2 | **Bot Threat Detected / Aggro** | `Scream` / `Yell` / `Taunt` / `Point` | `Enemy_Alert` / `Enemy_Spot_Player` | Bot spots player: jerks toward player, points weapon or screams/postures, transitions to chase. |
| D3 | **Bot Chase Run** | `Mutant Run` / `Sprint` / `Aggressive Run` | `Enemy_Chase_Run` / `Zombie_Run` | Frantic, aggressive sprint closing distance toward the player. In-place. |
| D4 | **Bot Attack / Shoot** | `Firing Rifle` / `Standing Melee Attack` | `Enemy_Shoot` / `Enemy_Attack` | Bot stops or strafes, raises weapon and fires bursts, or performs claw/strike if melee bot. |
| D5 | **Bot Stumble / Stagger** | `Stumble Backwards` / `Big Hit To Chest` | `Enemy_Stagger` / `Enemy_Knockback` | Heavy stagger breaking forward momentum when taking high damage. |
| D6 | **Bot Death** | `Mutant Dying` / `Flying Back Death` | `Enemy_Death` / `Bot_Death_Ragdoll` | Dramatic collapse upon reaching 0 HP. |

---

### Category E: Range NPC / Bystander (Phase 3 VN Coexistence)

| # | Action / Role | Probable Mixamo Name | Probable itch.io Name | Visual Description & Posture |
|---|---|---|---|---|
| E1 | **Range NPC Idle** | `Arms Crossed Idle` / `Standing Idle 01` | `NPC_Idle_ArmsCrossed` / `NPC_Waiting` | Casual bystander stance standing outside the firing lanes; arms crossed or resting hands on hips. |
| E2 | **Range NPC Talking / Explaining** | `Explaining` / `Talking` | `NPC_Talking_01` / `Dialog_Gesture` | Natural hand and head gestures while speaking (used during the `shooter_intro.dtl` timeline). |
| E3 | **Range NPC Pointing** | `Pointing` / `Directing` | `NPC_Point_Lane` | Pointing toward the target range to guide the player to the firing stalls. |

---

## 3. Prioritized Implementation Checklist

Use this checklist to track asset collection and preparation.

### Phase 1 Priority (Minimum Viable Combat Kit)
These animations are essential for implementing Phase 0 and Phase 1 of `shooter_demo_plan.md`:

- [x] **`combat_idle`**: Relaxed combat ready idle (`Rifle Idle`)
- [x] **`combat_walk_fwd`**: Forward walk with weapon (`Rifle Walk` - *In-Place*)
- [x] **`combat_run`**: Sprint with weapon (`Rifle Run` - *In-Place*)
- [x] **`combat_aim_idle`**: Iron sights / ADS stationary pose (`Rifle Aiming Idle`)
- [x] **`combat_shoot`**: Single-shot firing recoil (`Firing Rifle`)
- [x] **`combat_reload`**: Magazine reload (`Reloading` / `Rifle Reload`)

### Phase 1 Polish (Full 8-Way Locomotion & ADS Strafe)
- [ ] **`combat_walk_bwd`**: Backward walk (`Rifle Walk Backwards` - *In-Place*)
- [ ] **`combat_strafe_left`**: Left strafe (`Rifle Strafe Left` - *In-Place*)
- [ ] **`combat_strafe_right`**: Right strafe (`Rifle Strafe Right` - *In-Place*)
- [ ] **`combat_aim_walk_fwd`**: ADS forward walk
- [ ] **`combat_aim_strafe_left`**: ADS left strafe
- [ ] **`combat_aim_strafe_right`**: ADS right strafe
- [ ] **`combat_dash`**: Evasive combat roll (`Forward Roll` - *In-Place*)
- [ ] **`combat_jump_air`**: Jump loop (`Falling Idle` - *In-Place*)
- [ ] **`combat_jump_land`**: Land recovery (`Landing`)

### Phase 2 & 3 Additions (Reactions, Death & Range NPC)
- [ ] **`hit_flinch_chest`**: Light bullet impact reaction
- [ ] **`death_backward`**: Player/target death fall
- [ ] **`npc_range_idle`**: Range officer standing idle
- [ ] **`npc_range_talk`**: Range officer briefing gesture

### Phase 4 Additions (Hostile AI Bots)
- [ ] **`bot_patrol_walk`**: Enemy patrol cycle (*In-Place*)
- [ ] **`bot_spot_player`**: Alert reaction / roar
- [ ] **`bot_chase_run`**: Aggressive enemy run (*In-Place*)
- [ ] **`bot_attack`**: Firing or attacking animation
- [ ] **`bot_death`**: Enemy destruction / collapse

---

## 4. Suggested Folder Structure in Repository

When importing the animation assets into the project, organize them under `samples/shooter_demo/animations/` to keep them isolated from the visual novel core:

```
samples/shooter_demo/
├── animations/
│   ├── raw_fbx/                       # Downloaded .fbx source clips
│   │   ├── locomotion/
│   │   ├── combat/
│   │   └── bots/
│   ├── libraries/
│   │   ├── shooter_player_library.tres # Extracted Godot AnimationLibrary for Player
│   │   └── shooter_bot_library.tres    # Extracted Godot AnimationLibrary for Hostile Bots
│   └── trees/
│       ├── shooter_player_blendtree.tres # Extended AnimationTree for ADS/Shoot/Walk/Reload
│       └── shooter_bot_blendtree.tres
```

---

## 5. Next Steps for Implementation Agent

1. **Retargeting Verification**: In Godot's import dock, ensure the source skeleton uses `Animation` retargeting with standard `HumanoidBoneMap`.
2. **AnimationLibrary Assembly**: Extract clips into `shooter_player_library.tres` using clean keys matching the checklist IDs (`idle`, `walk_fwd`, `aim_idle`, `shoot`, `reload`).
3. **Upper-Body Layering in AnimationTree**:
   - Set up an `AnimationNodeOneShot` or `AnimationNodeAdd2` node for `SHOOT` (impulse trigger).
   - Set up a transition or blend node for `AIM` (smooth FOV + ADS pose blend).
   - Set up an upper-body masked `AnimationNodeOneShot` for `RELOAD` (filtered at `Spine` or `Chest`) so reload can play while moving.
