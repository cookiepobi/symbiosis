"""냥냥 빌리지 에셋 검사 — Blender 애드온과 자동 변환기(convert_assets.py)가 같이 쓰는 규칙.

bpy만 사용하고 상대 import를 하지 않으므로, 애드온 안에서도 단독 스크립트에서도 불러올 수 있다.
"""

import json
import os

import bpy
from mathutils import Vector

REFERENCE_COLLECTION = "NYANG_REFERENCE"

# glTF로 넘어가는(=Godot·웹에서 그대로 보이는) 셰이더 노드. 그 외 노드는 내보낼 때 사라진다.
GLTF_SAFE_NODES = {
    "ShaderNodeBsdfPrincipled", "ShaderNodeOutputMaterial", "ShaderNodeTexImage",
    "ShaderNodeNormalMap", "ShaderNodeMapping", "ShaderNodeTexCoord", "ShaderNodeUVMap",
    "ShaderNodeSeparateColor", "ShaderNodeCombineColor", "ShaderNodeSeparateRGB",
    "ShaderNodeCombineRGB", "ShaderNodeEmission", "ShaderNodeBsdfTransparent",
    "ShaderNodeMixShader", "ShaderNodeVertexColor", "ShaderNodeAttribute",
    "ShaderNodeMath", "ShaderNodeMix", "ShaderNodeMixRGB", "ShaderNodeInvert",
    "ShaderNodeBump", "NodeReroute", "NodeFrame", "ShaderNodeGroup",
    "ShaderNodeValue", "ShaderNodeRGB",
}


def default_rules_path():
    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "asset_rules.json"),  # 배포 zip 안
        os.path.normpath(os.path.join(here, "..", "..", "..", "godot", "assets", "asset_rules.json")),  # 저장소에서 직접 실행
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


def load_rules(path=None):
    path = path or default_rules_path()
    if not path:
        raise FileNotFoundError("asset_rules.json을 찾을 수 없습니다")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _reference_objects():
    coll = bpy.data.collections.get(REFERENCE_COLLECTION)
    return set(coll.all_objects) if coll else set()


def asset_objects(scene):
    refs = _reference_objects()
    return [o for o in scene.objects if o not in refs]


def world_bounds(objects, depsgraph):
    """평가된(모디파이어·포즈 적용) 상태의 월드 바운딩 박스. (min, max) 또는 None."""
    lo = Vector((float("inf"),) * 3)
    hi = Vector((float("-inf"),) * 3)
    found = False
    for obj in objects:
        if obj.type not in {"MESH", "CURVE", "SURFACE", "META", "FONT"}:
            continue
        ev = obj.evaluated_get(depsgraph)
        for corner in ev.bound_box:
            p = ev.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
            found = True
    return (lo, hi) if found else None


def triangle_count(objects, depsgraph):
    total = 0
    for obj in objects:
        if obj.type != "MESH":
            continue
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        total += sum(len(p.vertices) - 2 for p in mesh.polygons)
        ev.to_mesh_clear()
    return total


def _issue(issues, level, code, message):
    issues.append({"level": level, "code": code, "message": message})


def check_scene(scene, category, rules):
    """씬을 검사해 결과 dict를 돌려준다. level: error(변환 중단) / warning / info."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    objects = asset_objects(scene)
    issues = []
    cat_rules = rules["categories"].get(category)
    result = {
        "category": category,
        "dimensions": None,
        "tris": 0,
        "armatures": [],
        "shape_keys": [],
        "actions": [],
        "materials": [],
        "issues": issues,
    }

    if cat_rules is None:
        _issue(issues, "error", "unknown_category",
               f"카테고리 '{category}'가 규칙에 없습니다. 가능: {', '.join(rules['categories'])}")
        return result

    meshes = [o for o in objects if o.type == "MESH"]
    if not meshes:
        _issue(issues, "error", "no_mesh", "메시 오브젝트가 없습니다.")
        return result

    # 단위
    units = scene.unit_settings
    if units.system != "METRIC" or abs(units.scale_length - 1.0) > 1e-6:
        _issue(issues, "warning", "units",
               f"씬 단위가 Metric / Unit Scale 1.0이 아닙니다 (현재 {units.system}, {units.scale_length}).")

    # 크기
    bounds = world_bounds(objects, depsgraph)
    lo, hi = bounds
    size = hi - lo
    result["dimensions"] = [round(size.x, 4), round(size.y, 4), round(size.z, 4)]
    h_lo, h_hi = cat_rules["height"]
    if not (h_lo <= size.z <= h_hi):
        _issue(issues, "error", "height",
               f"높이 {size.z:.2f} m가 '{category}' 허용 범위 {h_lo:.2f}–{h_hi:.2f} m를 벗어났습니다.")

    # 원점: 바닥 중앙
    tol = rules.get("origin_tolerance_m", 0.02)
    if abs(lo.z) > tol:
        _issue(issues, "warning", "floor",
               f"에셋 바닥이 Z=0이 아닙니다 ({lo.z:+.3f} m). 게임에서 떠 있거나 묻혀 보입니다.")
    center = (lo + hi) / 2
    if max(abs(center.x), abs(center.y)) > max(0.05, 0.1 * max(size.x, size.y)):
        _issue(issues, "warning", "center",
               f"에셋이 원점 중앙에서 벗어나 있습니다 (X {center.x:+.2f}, Y {center.y:+.2f}).")

    # 스케일 미적용
    unapplied = [o.name for o in objects
                 if o.type in {"MESH", "ARMATURE"} and any(abs(s - 1.0) > 1e-4 for s in o.scale)]
    if unapplied:
        _issue(issues, "warning", "scale",
               "스케일이 적용되지 않은 오브젝트: " + ", ".join(unapplied[:8])
               + " (Ctrl+A → Scale)")

    # 폴리곤
    result["tris"] = triangle_count(meshes, depsgraph)
    if result["tris"] > cat_rules["max_tris"]:
        _issue(issues, "warning", "tris",
               f"삼각형 {result['tris']:,}개가 권장치 {cat_rules['max_tris']:,}개를 넘습니다 (모바일·웹 성능).")

    # 리깅 / 셰이프 키 / 액션
    result["armatures"] = [o.name for o in objects if o.type == "ARMATURE"]
    for o in meshes:
        if o.data.shape_keys:
            result["shape_keys"] += [k.name for k in o.data.shape_keys.key_blocks[1:]]
    result["actions"] = [a.name for a in bpy.data.actions if a.users > 0 or a.use_fake_user]
    if cat_rules.get("expect_armature") and not result["armatures"]:
        _issue(issues, "info", "armature", "아마추어(리그)가 없습니다. 움직이는 에셋이면 리깅이 필요합니다.")
    if result["shape_keys"] and any(o.modifiers for o in meshes):
        _issue(issues, "info", "modifiers_with_shapekeys",
               "Shape key와 모디파이어가 같이 있어 내보낼 때 모디파이어를 적용하지 않습니다. "
               "Subdivision 등은 미리 적용하거나 Armature만 남겨 주세요.")

    # 텍스처
    for img in bpy.data.images:
        if img.source != "FILE" or img.packed_file or img.users == 0:
            continue
        path = bpy.path.abspath(img.filepath)
        if not os.path.exists(path):
            _issue(issues, "error", "missing_texture",
                   f"텍스처 '{img.name}' 파일을 찾을 수 없습니다. File → External Data → Pack Resources로 묶어 주세요.")
        else:
            _issue(issues, "warning", "external_texture",
                   f"텍스처 '{img.name}'가 .blend 밖에 있습니다. Drive에 올리면 사라지니 Pack Resources 해 주세요.")

    # 셰이더 노드
    seen = set()
    for o in meshes:
        for slot in o.material_slots:
            mat = slot.material
            if not mat or mat.name in seen:
                continue
            seen.add(mat.name)
            result["materials"].append(mat.name)
            if not getattr(mat, "use_nodes", True) or not mat.node_tree:
                continue
            lost = sorted({n.bl_idname.replace("ShaderNode", "") for n in mat.node_tree.nodes
                           if n.bl_idname not in GLTF_SAFE_NODES})
            if lost:
                _issue(issues, "warning", "shader_nodes",
                       f"머티리얼 '{mat.name}'의 노드 {', '.join(lost)}는 게임으로 넘어가지 않습니다 "
                       "(텍스처로 Bake하거나 게임 셰이더로 다시 구현 필요).")

    return result


def has_errors(result):
    return any(i["level"] == "error" for i in result["issues"])
