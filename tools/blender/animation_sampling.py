"""Export baked Actions on a finer sampling grid without saving the .blend.

Scaling both Action time and scene FPS preserves seconds and poses while
letting the integer-only glTF sampling step retain subframe keys. Intended
for ACTIONS export, not NLA/scene animation or unbaked F-curve modifiers.
"""

import math
from contextlib import contextmanager


def action_fcurves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for slot in action.slots:
                bag = strip.channelbag(slot, ensure=False)
                if bag:
                    yield from bag.fcurves


@contextmanager
def temporary_sampling_grid(scene, actions, multiplier=1):
    """Temporarily multiply frames/FPS together; restore even on failure."""
    if type(multiplier) is not int or multiplier not in (1, 2, 4):
        raise ValueError("Animation sample multiplier must be 1, 2 or 4")
    if multiplier == 1:
        yield
        return

    curves, ranges = [], []
    for action in actions:
        ranges.append((action, action.frame_start, action.frame_end,
                       action.use_frame_range))
        for curve in action_fcurves(action):
            if curve.modifiers:
                raise ValueError("Bake F-curve modifiers before dense sampling")
            keys = [(tuple(key.co), tuple(key.handle_left),
                     tuple(key.handle_right)) for key in curve.keyframe_points]
            curves.append((curve, keys))

    old_fps = scene.render.fps
    old_base = scene.render.fps_base
    old_start, old_end = scene.frame_start, scene.frame_end
    old_frame, old_subframe = scene.frame_current, scene.frame_subframe
    new_fps = old_fps * multiplier
    if new_fps > scene.render.bl_rna.properties['fps'].hard_max:
        raise ValueError("Dense sampling would exceed Blender's FPS limit")

    try:
        for curve, keys in curves:
            for key, (co, left, right) in zip(curve.keyframe_points, keys):
                key.co.x = co[0] * multiplier
                key.handle_left.x = left[0] * multiplier
                key.handle_right.x = right[0] * multiplier
            curve.update()
        for action, start, end, explicit_range in ranges:
            if explicit_range:
                action.frame_end = end * multiplier
                action.frame_start = start * multiplier
        scene.render.fps = new_fps
        scene.frame_end = old_end * multiplier
        scene.frame_start = old_start * multiplier
        frame = (old_frame + old_subframe) * multiplier
        scene.frame_set(math.floor(frame), subframe=frame % 1)
        yield
    finally:
        for curve, keys in curves:
            # FCurve.update() can invalidate individual key RNA references.
            # Reacquire them from the curve instead of retaining key objects.
            for key, (co, left, right) in zip(curve.keyframe_points, keys):
                key.co = co
                key.handle_left = left
                key.handle_right = right
            curve.update()
        for action, start, end, explicit_range in ranges:
            if explicit_range:
                action.frame_start = start
                action.frame_end = end
        scene.render.fps = old_fps
        scene.render.fps_base = old_base
        scene.frame_start = old_start
        scene.frame_end = old_end
        scene.frame_set(old_frame, subframe=old_subframe)
