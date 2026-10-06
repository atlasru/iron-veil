# Production recovery checkpoint

The execution workspace disconnected with HTTP 409 `environment_offline` during the production asset upload. The larger overhaul has not been published. This branch currently runs the validated aim correction on the original v0.1 mission.

## Published and recoverable

- Aim correction commit: `aee6a2bad0b042a2b9e809372fd2fe2c546b9b4b`.
- Original indexed Wraith mesh: [wraith.glb](production-assets/wraith.glb), Git blob `c6a7e8dc60ad0bd5dc913edba9bbea0480dc0f42`.
- The staged mesh is archived in documentation; the running v0.1 rig is unchanged by this recovery checkpoint.

## Locally implemented, awaiting upload

Local commit: `c948ae40bed7d377fb38460c18df4a79a4bb7124`.
Local tree: `aba9fae7bd0dfb401dfec42fb5c1afae66960bec`.
Parent: `aee6a2bad0b042a2b9e809372fd2fe2c546b9b4b`.

Workspace: `/workspace/scratch/728152d31574/iron-veil`.
Shared Git directory belongs to `/workspace/scratch/7acbe1c31146/iron-veil`.
Upload manifest: `/workspace/scratch/728152d31574/tools/push-manifest.json` (263 entries; 99 binary files; 150,241,871 changed bytes). The GitHub upload uses create_blob/create_tree/create_commit and a leased update_ref because CLI push has no credentials. Read binaries in 196,608-byte chunks; larger exec output can truncate.

The local commit includes five original mechanical platforms, three mounted weapons, indexed Blender assets, an authored hangar and foundry, PBR maps, mechanical IK/foot locks/hydraulics, loadout and systems inspection, cinematics and cancellation handling, three boss phases, batched VFX, physical wreckage, five impact surfaces, original effects and a seven-state adaptive score. It also updates Android controls/settings, versioning, CI, native/runtime QA and the optional Gradle AAB path.

## Observed local verification

| Verification | Result |
|---|---|
| Aim matrix | 1,728 zero-spread configurations; maximum 0.00009 px projection error; no failures |
| Rules/settings | 26 checks passed |
| Integration | 25 checks passed |
| Machine/frontend systems | 17 checks passed; IK maximum link error 0.00000 m |
| Scripted mission | 18 kills, 24 shots, 24 hits; all checkpoints and completion; 10 checks, no failures |
| Audio sources | 59 clips/cues; no clipped source samples |
| APK export | Debug APK successfully exported and signing verified by Godot |
| Visual QA | Actual Vulkan Mobile/llvmpipe renders inspected; camera framing, lighting and hidden-floor defects corrected |

The scripted mission used positioning and immunity. It validates actual weapon hitboxes and progression, not human difficulty. Desktop software rendering is not physical-phone FPS.

Local APK: `build/IRON_VEIL_1.0.0-rc.1.apk` (about 103 MiB). It was built before the last source/QA additions and needs re-export after restoring execution. It could not be uploaded after disconnection. No new production release, AAB, final Android emulator validation or physical-phone 120 FPS measurement has been completed.

## Continue after reconnecting execution

1. Check the workspace and local Git commit before replacing anything.
2. Preserve the local production tree while fetching the current remote branch; this recovery checkpoint adds only documentation and the staged mesh.
3. Upload the production tree using the stored manifest and GitHub Git object tools, preserving modes and verifying the resulting tree SHA.
4. Finish visual/movie capture and profile the final source without concurrent renderer processes.
5. Run the new CI: import, rules, aim, integration, systems, rendering, APK signing, emulator native controls and scripted combat/checkpoints/completion. Attempt the Gradle AAB.
6. Publish a clearly labeled release candidate only after those checks; physical owner validation and a production signing key remain necessary before a store release.

Godot: 4.6.2 official. Blender: 4.5.4 LTS. Source art/audio are original; Barlow fonts use included SIL OFL licenses.
