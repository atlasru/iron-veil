# Shot convergence

The v0.1 HUD transformed `(800, 450)` into the Android display safe area. The
player fired along `-camera.global_basis.z`, through the full viewport center.
A left-only 90 px cutout at 2400×1080 moved the drawn reticle 45 px right of that
ray. Safe-area padding belongs to controls, not the camera's optical center.

The reticle now uses `Viewport.get_visible_rect().get_center()`. Both drawing
and `Camera3D.project_ray_origin/project_ray_normal` consume that exact point.
Camera pose is updated in the same physics step before firing. No compensating
angular offset or device-specific correction is applied.

The camera ray selects a world target. Each pellet travels from the actual
animated muzzle toward that target. A separate receiver-to-muzzle guard stops
barrels poking through thin obstacles. Muzzle-ray collision determines damage,
tracer endpoint and impact; all three use the same result.

`tests/aim.tscn` executes 1728 zero-spread combinations: 2/5/10/25/50/120 m;
first/third person; left/right shoulder; hipfire/ADS; FOV 60/78/100; render scale
0.55/0.85/1.0; 1280×720, 2400×1080, 1920×1200 and 1024×768. It also reproduces
the asymmetric-safe-area error and tests cover and tip-through-wall obstruction.
Local headless maximum projection error: 0.00009 px. This validates geometry,
not physical-phone input or GPU performance.

Development builds: F4 or `--aim-debug`. Cyan = camera ray; purple = convergence
ray; green = camera target; amber = actual trace; red = obstruction. Disabled by
default and unavailable in a release export.
