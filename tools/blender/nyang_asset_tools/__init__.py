"""냥냥 빌리지 에셋 도구 — 3D 뷰 사이드바(N) > '냥냥 에셋' 탭.

1. 카테고리 선택 → 2. 기준 모형 추가(집사·고양이·새끼·울타리·문, 게임과 같은 크기)
3. 검사 → 4. 문제 고치기(스케일 적용, 바닥 중앙 정렬) → 5. 저장 후 Drive의 같은 카테고리 폴더에 업로드
"""

import json

import bmesh
import bpy
from mathutils import Vector

from . import nyang_checks

bl_info = {
    "name": "Nyang Village Asset Tools",
    "author": "Nyang Village team",
    "version": (0, 1, 0),
    "blender": (4, 2, 0),
    "location": "View3D > Sidebar > 냥냥 에셋",
    "category": "Import-Export",
}

_rules_cache = None


def rules():
    global _rules_cache
    if _rules_cache is None:
        _rules_cache = nyang_checks.load_rules()
    return _rules_cache


def category_items(self, context):
    try:
        cats = rules()["categories"]
    except Exception:  # 규칙 파일이 없을 때도 패널은 떠야 한다
        return [("prop", "prop", "")]
    return [(key, f"{key} — {val['label']}", f"높이 {val['height'][0]}–{val['height'][1]} m")
            for key, val in cats.items()]


# ───── 기준 모형 ─────
def _make_box(name, size, location, collection):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], (v.co.z + 0.5) * size[2]))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    collection.objects.link(obj)
    return obj


def _make_cylinder(name, radius, height, location, collection):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=radius, radius2=radius, depth=height)
    for v in bm.verts:
        v.co.z += height / 2
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    collection.objects.link(obj)
    return obj


def _make_label(text, location, collection):
    curve = bpy.data.curves.new(f"label_{text}", type="FONT")
    curve.body = text  # Blender 기본 폰트는 한글이 없어 영문 표기
    curve.size = 0.12
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new(f"label_{text}", curve)
    obj.location = location
    obj.rotation_euler = (1.5708, 0, 0)
    collection.objects.link(obj)
    return obj


class NYANG_OT_add_references(bpy.types.Operator):
    bl_idname = "nyang.add_references"
    bl_label = "기준 모형 추가"
    bl_description = "게임 속 집사·고양이·울타리·문 크기의 반투명 모형을 에셋 왼쪽에 놓습니다 (내보낼 때 자동 제외)"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        bpy.ops.nyang.remove_references()
        coll = bpy.data.collections.new(nyang_checks.REFERENCE_COLLECTION)
        context.scene.collection.children.link(coll)
        coll.hide_render = True

        bounds = nyang_checks.world_bounds(nyang_checks.asset_objects(context.scene),
                                           context.evaluated_depsgraph_get())
        x = (bounds[0].x if bounds else 0.0) - 0.3
        refs = rules()["references"]
        for key in ["kitten", "cat_adult", "caretaker", "door", "fence"]:
            r = refs.get(key)
            if not r:
                continue
            w, h, d = r["width"], r["height"], r["depth"]
            x -= w / 2
            if key == "caretaker":
                obj = _make_cylinder(r["label"], w / 2, h, (x, 0, 0), coll)
            else:
                obj = _make_box(r["label"], (w, d, h), (x, 0, 0), coll)
            obj.display_type = "WIRE"
            obj.show_in_front = True
            obj.hide_select = True
            label = _make_label(f"{r['label']} {h:.2f}m", (x, 0, h + 0.08), coll)
            label.hide_select = True
            x -= w / 2 + 0.25
        self.report({"INFO"}, "기준 모형을 추가했습니다. Front 뷰(숫자패드 1)에서 비교해 보세요.")
        return {"FINISHED"}


class NYANG_OT_remove_references(bpy.types.Operator):
    bl_idname = "nyang.remove_references"
    bl_label = "기준 모형 제거"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        coll = bpy.data.collections.get(nyang_checks.REFERENCE_COLLECTION)
        if coll:
            for obj in list(coll.all_objects):
                data = obj.data
                bpy.data.objects.remove(obj, do_unlink=True)
                if data and data.users == 0:
                    if isinstance(data, bpy.types.Mesh):
                        bpy.data.meshes.remove(data)
                    elif isinstance(data, bpy.types.Curve):
                        bpy.data.curves.remove(data)
            bpy.data.collections.remove(coll)
        return {"FINISHED"}


class NYANG_OT_check(bpy.types.Operator):
    bl_idname = "nyang.check"
    bl_label = "게임 규칙 검사"
    bl_description = "크기·바닥 위치·스케일·텍스처·셰이더가 게임으로 잘 넘어가는지 검사합니다 (자동 변환기와 같은 규칙)"

    def execute(self, context):
        result = nyang_checks.check_scene(context.scene, context.scene.nyang_category, rules())
        context.window_manager.nyang_result = json.dumps(result, ensure_ascii=False)
        errors = sum(i["level"] == "error" for i in result["issues"])
        warnings = sum(i["level"] == "warning" for i in result["issues"])
        self.report({"ERROR" if errors else "INFO"}, f"오류 {errors}개, 경고 {warnings}개")
        return {"FINISHED"}


class NYANG_OT_apply_scale(bpy.types.Operator):
    bl_idname = "nyang.apply_scale"
    bl_label = "스케일 적용"
    bl_description = "선택한 오브젝트의 스케일을 1로 적용합니다 (Ctrl+A → Scale과 같음)"
    bl_options = {"REGISTER", "UNDO"}

    @classmethod
    def poll(cls, context):
        return context.mode == "OBJECT" and context.selected_objects

    def execute(self, context):
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return {"FINISHED"}


class NYANG_OT_snap_to_floor(bpy.types.Operator):
    bl_idname = "nyang.snap_to_floor"
    bl_label = "바닥 중앙에 맞추기"
    bl_description = "에셋 전체를 옮겨 바닥 중앙이 원점(0,0,0)에 오게 합니다"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        objects = nyang_checks.asset_objects(context.scene)
        bounds = nyang_checks.world_bounds(objects, context.evaluated_depsgraph_get())
        if not bounds:
            self.report({"WARNING"}, "메시가 없습니다")
            return {"CANCELLED"}
        lo, hi = bounds
        offset = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        for obj in objects:
            if obj.parent is None:
                obj.location -= offset
        return {"FINISHED"}


class NYANG_PT_panel(bpy.types.Panel):
    bl_label = "냥냥 빌리지 에셋"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "냥냥 에셋"

    def draw(self, context):
        layout = self.layout
        scene = context.scene
        layout.prop(scene, "nyang_category", text="카테고리")
        layout.label(text=f"Drive 업로드 폴더: {scene.nyang_category}/", icon="FILE_FOLDER")

        row = layout.row(align=True)
        row.operator("nyang.add_references", icon="OUTLINER_OB_ARMATURE")
        row.operator("nyang.remove_references", text="", icon="X")

        layout.operator("nyang.check", icon="CHECKMARK")
        row = layout.row(align=True)
        row.operator("nyang.apply_scale", icon="FULLSCREEN_EXIT")
        row.operator("nyang.snap_to_floor", icon="SNAP_FACE")

        raw = context.window_manager.nyang_result
        if not raw:
            return
        result = json.loads(raw)
        box = layout.box()
        if result.get("dimensions"):
            w, d, h = result["dimensions"]
            box.label(text=f"크기 W {w:.2f} × D {d:.2f} × H {h:.2f} m")
            box.label(text=f"삼각형 {result['tris']:,}개")
        if result["armatures"]:
            box.label(text="리그: " + ", ".join(result["armatures"]), icon="ARMATURE_DATA")
        if result["shape_keys"]:
            box.label(text="Shape key: " + ", ".join(result["shape_keys"][:6]), icon="SHAPEKEY_DATA")
        if result["actions"]:
            box.label(text="애니메이션: " + ", ".join(result["actions"][:6]), icon="ACTION")
        icons = {"error": "CANCEL", "warning": "ERROR", "info": "INFO"}
        if not result["issues"]:
            box.label(text="문제 없음 — 저장 후 업로드하세요", icon="CHECKMARK")
        for issue in result["issues"]:
            col = box.column(align=True)
            # 긴 문장은 패널 폭에 맞춰 나눠 표시
            words, line = issue["message"].split(" "), ""
            first = True
            for word in words:
                if len(line) + len(word) > 34:
                    col.label(text=line, icon=icons[issue["level"]] if first else "BLANK1")
                    first, line = False, ""
                line += word + " "
            col.label(text=line, icon=icons[issue["level"]] if first else "BLANK1")


classes = (
    NYANG_OT_add_references,
    NYANG_OT_remove_references,
    NYANG_OT_check,
    NYANG_OT_apply_scale,
    NYANG_OT_snap_to_floor,
    NYANG_PT_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.nyang_category = bpy.props.EnumProperty(name="카테고리", items=category_items)
    bpy.types.WindowManager.nyang_result = bpy.props.StringProperty(default="")


def unregister():
    del bpy.types.WindowManager.nyang_result
    del bpy.types.Scene.nyang_category
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
