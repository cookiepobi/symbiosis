"""Run: blender -b --factory-startup -P tools/blender/test_animation_sampling.py"""

import json
import struct
import sys
import tempfile
import os
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import bpy

HERE = Path(__file__).resolve().parent
TEST_TMP = os.environ.get('NYANG_TEST_TMPDIR')
if TEST_TMP:
    TEST_TMP = Path(TEST_TMP).resolve()
    TEST_TMP.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(HERE))
from animation_sampling import action_fcurves, temporary_sampling_grid  # noqa: E402
import convert_assets  # noqa: E402


def snapshot(scene):
    return {
        "fps": (scene.render.fps, scene.render.fps_base),
        "range": (scene.frame_start, scene.frame_end),
        "frame": (scene.frame_current, scene.frame_subframe),
        "actions": [
            (a.name, a.frame_start, a.frame_end, a.use_frame_range, a.use_fake_user,
             [(fc.data_path, fc.array_index,
               [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right),
                 k.interpolation) for k in fc.keyframe_points])
              for fc in action_fcurves(a)]) for a in bpy.data.actions
        ],
    }


class SamplingTests(unittest.TestCase):
    def setUp(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.scene.render.fps = 30
        self.scene.frame_start, self.scene.frame_end = 1, 3
        data = bpy.data.armatures.new("Rig")
        self.rig = bpy.data.objects.new("Rig", data)
        self.scene.collection.objects.link(self.rig)
        bpy.context.view_layer.objects.active = self.rig
        self.rig.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        root = data.edit_bones.new("root")
        root.head, root.tail, root.use_deform = (0, 0, 0), (0, 0, .1), False
        hips = data.edit_bones.new("hips")
        hips.head, hips.tail, hips.parent = (0, 0, 0), (0, 0, 1), root
        bpy.ops.object.mode_set(mode='OBJECT')
        pb = self.rig.pose.bones['hips']
        for f, x in ((1, 0), (1.25, .002), (2, 0), (3, 0)):
            pb.location.x = x
            pb.keyframe_insert(data_path='location', frame=f)
        self.action = self.rig.animation_data.action
        self.action.name = 'groom_loop'
        self.action.use_fake_user = True
        self.action.use_frame_range = True
        self.action.frame_start, self.action.frame_end = 1, 3

        mesh = bpy.data.meshes.new('Body')
        mesh.from_pydata([(0, 0, 0), (.1, 0, 0), (0, .1, .1)], [], [(0, 1, 2)])
        self.body = bpy.data.objects.new('Body', mesh)
        self.scene.collection.objects.link(self.body)
        self.body.parent = self.rig
        self.body.vertex_groups.new(name='hips').add([0, 1, 2], 1., 'REPLACE')
        self.body.modifiers.new('Armature', 'ARMATURE').object = self.rig
        self.body.shape_key_add(name='Basis')
        key = self.body.shape_key_add(name='groom_soften')
        key.data[0].co.y += .001
        keys = mesh.shape_keys
        keys.animation_data_create()
        keys.animation_data.action = self.action
        keys.animation_data.action_slot = self.action.slots.new(id_type='KEY', name=keys.name)
        for f, value in ((1, 0), (1.25, 1), (2, 0), (3, 0)):
            key.value = value
            key.keyframe_insert(data_path='value', frame=f)
        other = self.action.copy()
        other.name = 'idle_loop'
        other.use_fake_user = True
        other.use_frame_range = False
        self.scene.frame_set(1, subframe=.25)

    def points(self):
        ev = self.body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        return [ev.matrix_world @ v.co for v in ev.data.vertices]

    def test_seconds_poses_slots_and_ranges_are_preserved(self):
        original = snapshot(self.scene)
        samples = {}
        for f in (1, 1.25, 1.5, 2.5, 3):
            self.scene.frame_set(int(f), subframe=f % 1)
            samples[f] = self.points()
        self.scene.frame_set(1, subframe=.25)
        with temporary_sampling_grid(self.scene, bpy.data.actions, 4):
            self.assertEqual(self.scene.render.fps, 120)
            self.assertEqual(tuple(self.action.frame_range), (4., 12.))
            self.assertEqual(self.scene.frame_current, 5)
            for f, before in samples.items():
                self.scene.frame_set(int(f * 4), subframe=(f * 4) % 1)
                self.assertLess(max((a - b).length for a, b in zip(before, self.points())), 1e-7)
                self.assertAlmostEqual(f / 30, (f * 4) / 120)
        self.assertEqual(snapshot(self.scene), original)

    def test_failure_restores_timeline(self):
        original = snapshot(self.scene)
        with self.assertRaisesRegex(RuntimeError, 'export failed'):
            with temporary_sampling_grid(self.scene, bpy.data.actions, 4):
                raise RuntimeError('export failed')
        self.assertEqual(snapshot(self.scene), original)

    def test_default_is_noop_and_invalid_values_do_not_mutate(self):
        original = snapshot(self.scene)
        with temporary_sampling_grid(self.scene, bpy.data.actions):
            self.assertEqual(snapshot(self.scene), original)
        for multiplier in (0, -1, 1.5, 3):
            with self.assertRaises(ValueError):
                with temporary_sampling_grid(self.scene, bpy.data.actions, multiplier):
                    self.fail('Invalid multiplier was accepted')
        self.assertEqual(snapshot(self.scene), original)

    def test_unbaked_modifiers_are_rejected(self):
        fc = next(action_fcurves(self.action))
        fc.modifiers.new(type='NOISE')
        original = snapshot(self.scene)
        with self.assertRaisesRegex(ValueError, 'Bake F-curve modifiers'):
            with temporary_sampling_grid(self.scene, bpy.data.actions, 4):
                self.fail('Unbaked modifier was accepted')
        self.assertEqual(snapshot(self.scene), original)

    def test_export_has_subframe_times_deform_only_and_restores_scene(self):
        original = snapshot(self.scene)
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            if TEST_TMP:
                self.assertTrue(Path(folder).resolve().is_relative_to(TEST_TMP))
            path = Path(folder) / 'sample.glb'
            convert_assets.export_glb(str(path), True, 4)
            raw = path.read_bytes()
            count = struct.unpack_from('<I', raw, 12)[0]
            manifest = json.loads(raw[20:20 + count])
            self.assertEqual({a['name'] for a in manifest['animations']}, {'groom_loop', 'idle_loop'})
            skin = manifest['skins'][0]
            self.assertEqual([manifest['nodes'][i]['name'] for i in skin['joints']], ['hips'])
            self.assertIn('groom_soften', manifest['meshes'][0]['extras']['targetNames'])
            animation = next(a for a in manifest['animations'] if a['name'] == 'groom_loop')
            inputs = [manifest['accessors'][s['input']] for s in animation['samplers']]
            self.assertGreaterEqual(max(a['count'] for a in inputs), 9)
            self.assertAlmostEqual(max(a['max'][0] for a in inputs), 2 / 30, places=6)
        self.assertEqual(snapshot(self.scene), original)

    def test_profile_change_invalidates_source_cache(self):
        with tempfile.TemporaryDirectory(dir=TEST_TMP) as folder:
            if TEST_TMP:
                self.assertTrue(Path(folder).resolve().is_relative_to(TEST_TMP))
            base = Path(folder)
            (base / 'src' / 'cat').mkdir(parents=True)
            (base / 'src' / 'cat' / 'cat_base.blend').write_bytes(b'fixture')
            rules = base / 'rules.json'
            rules.write_text('{}')
            args = SimpleNamespace(src=str(base / 'src'), out=str(base / 'out'),
                                   rules=str(rules), report=str(base / 'report.md'),
                                   force=False, animation_sample_multiplier=1)
            result = dict(dimensions=[.5, .5, .6], tris=1, armatures=['Rig'],
                          shape_keys=['groom_soften'], actions=['groom_loop'], issues=[])

            def write_glb(path, _has_keys, _multiplier):
                Path(path).write_bytes(b'fixture')

            with patch.object(convert_assets, 'parse_args', return_value=args), \
                    patch.object(convert_assets, 'load_source') as load, \
                    patch.object(convert_assets, 'remove_references'), \
                    patch.object(convert_assets.nyang_checks, 'check_scene', return_value=result), \
                    patch.object(convert_assets, 'export_glb', side_effect=write_glb):
                convert_assets.main()
                self.assertEqual(load.call_count, 1)
                convert_assets.main()
                self.assertEqual(load.call_count, 1)
                args.animation_sample_multiplier = 4
                convert_assets.main()
                self.assertEqual(load.call_count, 2)
            manifest = json.loads((base / 'out' / 'manifest.json').read_text())
            self.assertEqual(manifest['cat/cat_base.blend']['export_profile']['animation_sample_multiplier'], 4)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(SamplingTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise SystemExit(1)
