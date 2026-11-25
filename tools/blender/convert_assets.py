"""Drive에서 내려받은 원본(.blend/.fbx/.obj/.gltf)을 검사하고 Godot용 .glb로 변환한다.

실행 (Blender 5.3):
  blender -b --factory-startup -P tools/blender/convert_assets.py -- \
      --src drive_src --out godot/assets/models \
      --rules godot/assets/asset_rules.json --report asset-report.md [--force]

폴더 규칙: <src>/<카테고리>/<이름>.blend  →  <out>/<카테고리>/<이름>.glb
변경 여부는 <out>/manifest.json에 저장한 원본 SHA-256으로 판단한다.
"""

import argparse
import datetime
import json
import os
import re
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "nyang_asset_tools"))
sys.path.insert(0, os.path.join(HERE, "..", "sync"))
import nyang_checks  # noqa: E402
from asset_files import SOURCE_EXTS, file_sha256, iter_sources, slugify  # noqa: E402
from animation_sampling import temporary_sampling_grid  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--rules", required=True)
    p.add_argument("--report", default="asset-report.md")
    p.add_argument("--force", action="store_true")
    p.add_argument("--animation-sample-multiplier", type=int, choices=(1, 2, 4), default=1,
                   help="Export-only frame/FPS multiplier for baked subframe keys (4 = quarter frames)")
    return p.parse_args(argv)


def load_source(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext in {".glb", ".gltf"}:
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        raise ValueError(f"지원하지 않는 형식: {ext}")


def remove_references():
    coll = bpy.data.collections.get(nyang_checks.REFERENCE_COLLECTION)
    if coll:
        for obj in list(coll.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(coll)


def export_glb(path, has_shape_keys, animation_sample_multiplier=1):
    """Blender 버전마다 옵션 이름이 조금씩 달라서, 존재하는 옵션만 골라 넘긴다."""
    wanted = {
        "filepath": path,
        "export_format": "GLB",
        "use_selection": False,
        "use_visible": False,
        "export_yup": True,
        "export_apply": not has_shape_keys,  # Shape key가 있으면 모디파이어 적용 불가
        "export_animations": True,
        "export_animation_mode": "ACTIONS",
        "export_force_sampling": True,
        "export_frame_step": 1,
        "export_optimize_animation_size": False,
        "export_def_bones": True,
        "export_anim_slide_to_zero": True,
        "export_skins": True,
        "export_morph": True,
        "export_materials": "EXPORT",
        "export_image_format": "AUTO",
        "export_cameras": False,
        "export_lights": False,
        "export_extras": True,
    }
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    with temporary_sampling_grid(bpy.context.scene, bpy.data.actions,
                                 animation_sample_multiplier):
        bpy.ops.export_scene.gltf(**{k: v for k, v in wanted.items() if k in props})


def fmt_dims(dims):
    return "–" if not dims else f"{dims[0]:.2f}×{dims[1]:.2f}×**{dims[2]:.2f}**"


def main():
    args = parse_args()
    rules = nyang_checks.load_rules(args.rules)
    os.makedirs(args.out, exist_ok=True)
    manifest_path = os.path.join(args.out, "manifest.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)

    rows = []
    export_profile = {"version": 2, "animation_sample_multiplier": args.animation_sample_multiplier,
                      "animation_mode": "ACTIONS", "deform_only": True,
                      "force_sampling": True, "optimize_animation_size": False}
    for rel, category, src_path in iter_sources(args.src):
        digest = file_sha256(src_path)
        name = slugify(os.path.splitext(os.path.basename(rel))[0])
        out_rel = f"{category}/{name}.glb"
        out_path = os.path.join(args.out, out_rel)
        prev = manifest.get(rel)
        if (not args.force and prev and prev.get("sha256") == digest
                and prev.get("export_profile") == export_profile
                and (prev.get("status") != "converted" or os.path.exists(out_path))):
            continue

        entry = {"source": rel, "sha256": digest, "category": category, "output": None,
                 "export_profile": export_profile,
                 "checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")}
        try:
            load_source(os.path.abspath(src_path))
            remove_references()
            result = nyang_checks.check_scene(bpy.context.scene, category, rules)
            entry.update({k: result[k] for k in ("dimensions", "tris", "armatures", "shape_keys",
                                                  "actions", "issues")})
            if nyang_checks.has_errors(result):
                entry["status"] = "rejected"
            else:
                os.makedirs(os.path.dirname(out_path), exist_ok=True)
                export_glb(os.path.abspath(out_path), bool(result["shape_keys"]),
                           args.animation_sample_multiplier)
                entry["status"] = "converted"
                entry["output"] = out_rel
        except Exception as exc:  # 한 파일이 깨져도 나머지는 계속 처리
            entry["status"] = "failed"
            entry["issues"] = [{"level": "error", "code": "exception", "message": str(exc)}]
        manifest[rel] = entry
        rows.append(entry)
        print(f"[{entry['status']}] {rel}")

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(manifest.items())), f, ensure_ascii=False, indent=2)
        f.write("\n")
    write_report(args.report, rows)


def write_report(path, rows):
    icon = {"converted": "✅", "rejected": "⛔", "failed": "💥"}
    lines = ["## Google Drive 에셋 동기화 결과", ""]
    if not rows:
        lines.append("변경된 에셋이 없습니다.")
    else:
        lines += ["| 상태 | 원본 | 크기 W×D×H (m) | 삼각형 | 리그 / Shape key / 애니메이션 |",
                  "|---|---|---|---:|---|"]
        for r in rows:
            extras = " / ".join(str(len(r.get(k) or [])) for k in ("armatures", "shape_keys", "actions"))
            lines.append(f"| {icon[r['status']]} {r['status']} | `{r['source']}` | {fmt_dims(r.get('dimensions'))} "
                         f"| {r.get('tris') or 0:,} | {extras} |")
        lines.append("")
        for r in rows:
            issues = r.get("issues") or []
            if not issues:
                continue
            lines.append(f"### `{r['source']}`")
            for i in issues:
                mark = {"error": "⛔", "warning": "⚠️", "info": "ℹ️"}[i["level"]]
                lines.append(f"- {mark} {i['message']}")
            lines.append("")
        lines += ["", "⛔ 항목은 변환하지 않았습니다. 업로드한 사람이 Blender 애드온 `냥냥 에셋` 패널로 고친 뒤 "
                  "같은 이름으로 다시 올리면 다음 동기화 때 자동으로 반영됩니다."]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
