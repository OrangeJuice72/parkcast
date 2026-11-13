"""Package only the app source, project, tests, and setup docs; no local tools or caches."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
destination = ROOT / "dist/ParkCast-source.zip"
destination.parent.mkdir(exist_ok=True)
files = [ROOT / name for name in ["README.md", "TESTING.md", "SIDELOAD.md", "Package.swift", ".gitignore", ".gitattributes"]]
for folder in ["ParkCast", "Sources", "Tests", "Config", "ParkCast.xcodeproj", "scripts", ".github", "try"]:
    files.extend(p for p in (ROOT / folder).rglob("*")
                 if p.is_file() and "__pycache__" not in p.parts and "xcuserdata" not in p.parts)
with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
    for file in sorted(files):
        archive.write(file, "ParkCast/" + file.relative_to(ROOT).as_posix())
with ZipFile(destination) as archive:
    assert archive.testzip() is None
    assert "ParkCast/ParkCast.xcodeproj/project.pbxproj" in archive.namelist()
    assert not any(".tools/" in name or "reference.json" in name for name in archive.namelist())
    print(f"Packaged {len(archive.namelist())} files: {destination} ({destination.stat().st_size:,} bytes)")
