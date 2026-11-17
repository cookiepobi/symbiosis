"""Drive 원본 폴더를 훑는 공통 함수 (Blender 없이도 실행 가능)."""

import hashlib
import os
import re
import unicodedata

SOURCE_EXTS = {".blend", ".fbx", ".obj", ".glb", ".gltf"}


def slugify(name):
    name = unicodedata.normalize("NFKC", name).strip().lower()
    name = re.sub(r"[^0-9a-z가-힣]+", "_", name).strip("_")
    return name or "asset"


def file_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def iter_sources(src_root):
    """(상대경로, 카테고리, 절대경로)를 돌려준다. 카테고리는 최상위 폴더 이름."""
    for dirpath, dirnames, filenames in os.walk(src_root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith((".", "_")))
        for fname in sorted(filenames):
            if os.path.splitext(fname)[1].lower() not in SOURCE_EXTS:
                continue
            full = os.path.join(dirpath, fname)
            rel = os.path.relpath(full, src_root).replace(os.sep, "/")
            if "/" not in rel:
                category = "_root"  # 카테고리 폴더 밖에 올린 파일 → 검사에서 오류로 표시됨
            else:
                category = slugify(rel.split("/", 1)[0])
            yield rel, category, full
