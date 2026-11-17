"""Blender 애드온 설치용 zip을 만든다: python tools/blender/build_addon.py → dist/nyang_asset_tools.zip

규칙 파일(godot/assets/asset_rules.json)을 zip 안에 같이 넣으므로, 규칙을 바꾸면 zip을 다시 만들어 배포한다.
"""

import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ADDON = os.path.join(HERE, "nyang_asset_tools")
RULES = os.path.join(ROOT, "godot", "assets", "asset_rules.json")
OUT = os.path.join(ROOT, "dist", "nyang_asset_tools.zip")


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for name in sorted(os.listdir(ADDON)):
            path = os.path.join(ADDON, name)
            if name == "asset_rules.json" or not os.path.isfile(path) or name.endswith(".pyc"):
                continue
            z.write(path, name)
        z.write(RULES, "asset_rules.json")
    print(OUT)


if __name__ == "__main__":
    main()
