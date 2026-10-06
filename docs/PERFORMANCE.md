# Performance validation

Measured on 2026-10-06 in a Linux container, Ubuntu 24.04, Godot 4.6.2,
Vulkan **Mobile**, **llvmpipe (LLVM 20.1.2, 256 bits)** software rendering.
Window 1280×720, High preset, 85% 3D render scale, MSAA 2x, 70m shadows.
The renderer is CPU-emulated; these measurements do not predict Nothing Phone (3)
FPS. No physical Android hardware was attached.

Four scenarios run for approximately nine seconds each: two seconds warm-up,
then seven seconds sampling. Heavy combat adds eight android/heavy opponents
in addition to the initial encounter, with invulnerability during measurement.
Values below use monotonic **wall-clock frame intervals**, not Godot's clamped
simulation delta. Draw calls and primitives are final-frame counters, not averages.

| Scenario | FPS | Mean frame ms | P95 ms | Draw calls | Primitives |
|---|---:|---:|---:|---:|---:|
| exploration_third | 7.91 | 126.45 | 243.41 | 757 | 59710 |
| exploration_first | 8.89 | 112.54 | 137.60 | 746 | 55816 |
| combat_third | 6.26 | 159.62 | 180.54 | 1161 | 128264 |
| combat_first | 6.36 | 157.11 | 192.12 | 1045 | 115832 |

Raw local data: [benchmark-local.json](benchmark-local.json). Every CI run
uploads its own environment-labelled JSON and actual viewport captures. They
are independent measurements and may differ from this container.

## Engineering results

- Shared geometry/material resources, static MultiMesh groups in 16×20m spatial
  buckets, frustum/distance culling and conservative box occluders for large
  solid structures. Closed gate occluders move with their physical doors.
- Robot opaque materials are vertex-colored into one surface per articulated
  part; emitters remain separate. A Wraith source model has 19 mesh surfaces.
- Texture mipmaps and desktop/mobile VRAM compression. Android export includes
  the appropriate mobile texture variant.
- Shadow distance, localized lights, steam and particle budgets follow settings.
  Transient muzzle lights are pooled; debris is bounded and removed on timers.
- AI decisions run at 0.17s near combat, 0.5s at distance, and stop beyond 80m.
  A* path refresh is throttled. Sleeping rigid props do not get per-frame writes.
- Configurable FPS/render scale and optional dynamic resolution. Gameplay physics
  remains 60Hz; visual quality controls never change damage or AI rules.

Software rendering remains the principal bottleneck in this environment.
The demanding combat case also increases procedural animation/hitbox updates,
physics work, transparent smoke and draw submissions. Godot's process and physics
monitors are recorded in the JSON, but process time can include renderer waits;
it is not a dedicated GPU timer. GPU timestamps were unavailable here.

The 60 FPS target, actual touch/gyro ergonomics and sustained thermal behavior on
Nothing Phone (3) remain **unverified**. No device performance estimate is claimed.
Start with High; adjust render scale/shadows if hardware measurements require it.
Ultra is explicitly experimental. This report is not a thermal certification.

## Runtime validation

26 logic checks; 22 scene integration checks cover actual movement, jump/landing,
stairs, perspective invariants, three concurrent touches, reachable animated arm
hitboxes, localized damage, camera collision, obstruction rays, checkpoint doors,
Warden interlock and mission completion. Actual Vulkan frames were inspected.

The CI Android job installs the real APK into an API 35 x86_64 emulator and records
launcher, gameplay, perspective and resume screenshots plus logcat. Physical-device
validation is outstanding. APK signatures and both included ABIs are verified.
