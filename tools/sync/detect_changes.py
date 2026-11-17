"""Blender를 내려받기 전에 변환할 파일이 있는지 빠르게 확인한다.

python tools/sync/detect_changes.py drive_src godot/assets/models/manifest.json
→ GITHUB_OUTPUT에 changed=<개수> 기록 (로컬에서는 출력만)
"""

import json
import os
import sys

from asset_files import file_sha256, iter_sources


def main(src, manifest_path):
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)
    changed = [rel for rel, _, full in iter_sources(src)
               if manifest.get(rel, {}).get("sha256") != file_sha256(full)]
    for rel in changed:
        print("변경:", rel)
    print(f"변경된 원본 {len(changed)}개")
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write(f"changed={len(changed)}\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
