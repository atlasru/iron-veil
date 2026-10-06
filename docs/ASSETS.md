# Asset provenance

| Content | Source / author | License | Workflow |
|---|---|---|---|
| Wraith robot and articulated armor | IRON//VEIL / atlasru | MIT | Original beveled convex hard-surface geometry, glTF 2.0 |
| Three weapons | IRON//VEIL / atlasru | MIT | Original receiver, barrels, magazines and coil geometry |
| Industrial facility | IRON//VEIL / atlasru | MIT | Original authored procedural layout and assembly code |
| Metal, armor, floor, concrete and normals | IRON//VEIL / atlasru | MIT | Seeded procedural wear, panel seams, fasteners and surface gradients |
| Smoke / scorch / icon | IRON//VEIL / atlasru | MIT | Original procedural alpha textures and SVG |
| Eleven audio assets | IRON//VEIL / atlasru | MIT | Original oscillators, noise, filtering and envelopes; no samples |
| Godot 4.6.2 runtime | Godot contributors | MIT + permissive component licenses | Official pinned export templates |

Generator: `tools/make_assets.py`, seed 7119. Combat/effects use separate seeded
random generators. No copied, ripped or externally licensed gameplay assets.

Engine license files are verbatim from the Godot **4.6.2-stable** source tag:
[LICENSE.txt](https://github.com/godotengine/godot/blob/4.6.2-stable/LICENSE.txt)
and [COPYRIGHT.txt](https://github.com/godotengine/godot/blob/4.6.2-stable/COPYRIGHT.txt).

Engine choice: Godot offers a freely redistributable Android runtime and a
reproducible CLI export path without an editor account. Mobile renderer provides
Vulkan PBR, fog, glow, instancing and shadows at lower baseline cost than Forward+.
This project uses Mobile's supported feature set; it does not claim Forward+-only
GI or volumetrics. [Renderer reference](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html).
