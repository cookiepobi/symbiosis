# Subframe animation export

The glTF exporter samples at integer frames. In Blender 5.3, disabling
`export_force_sampling` also disables `export_def_bones` internally, so it
cannot preserve both subframe contact keys and a deform-only skin.

For baked Actions with quarter-frame foot corrections:

```sh
blender -b --factory-startup -P tools/blender/convert_assets.py -- \
  --src drive_src --out godot/assets/models \
  --rules godot/assets/asset_rules.json --report asset-report.md \
  --animation-sample-multiplier 4
```

The converter temporarily scales Action key times, Bezier handle times,
explicit Action ranges, scene playback range and FPS together. A 30 FPS
source is sampled at 120 samples/second; a 0.8 second walk remains 0.8
seconds. This is an export sampling grid, not a change to team playback FPS.
The original timeline is restored in `finally`, including failed exports.
No `.blend` is saved. This mode expects baked Actions; F-curve modifiers
must be baked first. It is not an NLA/scene-animation time remapper.

The workflow opts into 4; command-line users retain the default multiplier
1. Animation mode, always-sample, no key optimization and deform-only export
are explicit. The manifest includes the export profile so unchanged source
files are re-converted when the sampling profile changes.

Run Blender regression tests:

```sh
blender -b --factory-startup -P tools/blender/test_animation_sampling.py
```

Asset validation (Blender 5.3, six movement clips, three body morph settings,
half-source-frame measurements): regular sampling reached 3.854 mm contact
height; sampling disabled reached 2.973 mm but exported 33 joints including
the non-deforming root. Multiplier 4 reached 2.974 mm with 32 deform joints.
The model files used for this validation are not included in the repository.
