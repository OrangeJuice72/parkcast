"""Check project wiring/plists and optionally Swift syntax. This is not an iOS build."""
from pathlib import Path
import plistlib
import json
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tools/python"))

def read_project(path):
    # Parse the OpenStep plist on disk instead of regenerating/overwriting signing settings.
    pattern = r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+'
    tokens = [t for t in re.findall(pattern, path.read_text(encoding="utf-8"))
              if not t.startswith("//") and not t.startswith("/*")]
    position = 0

    def take(expected=None):
        nonlocal position
        token = tokens[position]
        position += 1
        if expected is not None:
            assert token == expected, (token, expected)
        return token

    def parse():
        token = take()
        if token == "{":
            result = {}
            while tokens[position] != "}":
                key = parse()
                assert key not in result, f"Duplicate key: {key}"
                take("=")
                result[key] = parse()
                take(";")
            take("}")
            return result
        if token == "(":
            result = []
            while tokens[position] != ")":
                result.append(parse())
                if tokens[position] == ",":
                    take(",")
            take(")")
            return result
        return json.loads(token) if token.startswith('"') else token

    result = parse()
    assert position == len(tokens), "Trailing project data"
    return result


def main():
    document = read_project(ROOT / "ParkCast.xcodeproj/project.pbxproj")
    objects = document["objects"]
    assert document["rootObject"] in objects
    for key, obj in objects.items():
        assert re.fullmatch(r"[A-F0-9]{24}", key), key
        for field in ["fileRef", "productReference", "buildConfigurationList", "mainGroup", "productRefGroup"]:
            if field in obj:
                assert obj[field] in objects, (key, field)
        for field in ["children", "files", "buildConfigurations", "buildPhases", "targets"]:
            for value in obj.get(field, []):
                assert value in objects, (key, field, value)
        if obj["isa"] == "PBXFileReference" and obj.get("sourceTree") == "SOURCE_ROOT":
            assert (ROOT / obj["path"]).is_file(), obj["path"]
        if obj["isa"] == "PBXNativeTarget":
            phases = [objects[phase] for phase in obj["buildPhases"]]
            source_phase = next(p for p in phases if p["isa"] == "PBXSourcesBuildPhase")
            assert len(source_phase["files"]) == len(set(source_phase["files"]))
            source_paths = [objects[objects[b]["fileRef"]]["path"] for b in source_phase["files"]]
            assert "ParkCast/ParkCastApp.swift" in source_paths
            assert "Sources/ParkCastCore/Media.swift" in source_paths
    for path in (ROOT / "Config").glob("*"):
        plistlib.loads(path.read_bytes())
    base = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
    assert "NSAppTransportSecurity" not in base
    assert base["UIBackgroundModes"] == ["audio"]
    entitlements = plistlib.loads((ROOT / "Config/CarPlay.entitlements").read_bytes())
    assert entitlements == {"com.apple.developer.carplay-video": True}
    for path in (ROOT / "ParkCast.xcodeproj/xcshareddata/xcschemes").glob("*.xcscheme"):
        for ref in ET.parse(path).iter("BuildableReference"):
            assert objects[ref.attrib["BlueprintIdentifier"]]["isa"] == "PBXNativeTarget"
    print("PASS: source files, target references, schemes, plists, and entitlement separation.")
    try:
        from tree_sitter import Language, Parser
        import tree_sitter_swift
    except ImportError:
        print("SKIP: optional Swift syntax parser not installed. See README for installation.")
        return
    parser = Parser(Language(tree_sitter_swift.language()))
    paths = [ROOT / "Package.swift"]
    paths += list((ROOT / "ParkCast").glob("*.swift"))
    paths += list((ROOT / "Sources").rglob("*.swift"))
    paths += list((ROOT / "Tests").rglob("*.swift"))
    failures = []
    for path in paths:
        tree = parser.parse(path.read_bytes())
        stack = [tree.root_node]
        while stack:
            node = stack.pop()
            if node.type == "ERROR" or node.is_missing:
                failures.append(f"{path.relative_to(ROOT)}:{node.start_point.row + 1}: {node.type}")
            stack.extend(node.children)
    if failures:
        raise SystemExit("Swift syntax errors:\n" + "\n".join(failures))
    print(f"PASS: parsed {len(paths)} Swift files without syntax errors.")
    print("NOT RUN: Apple SDK type checking, Swift tests, iOS runtime, physical AirPlay/CarPlay.")


if __name__ == "__main__":
    main()
