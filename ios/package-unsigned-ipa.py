"""Package an unsigned Xcode device archive for local Apple ID signing."""

import argparse
import plistlib
import stat
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    app = args.archive / "Products" / "Applications" / "ERP.app"
    executable = app / "ERP"
    if not executable.is_file():
        parser.error(f"The device archive has no ERP executable: {app}")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != "sex.erp.ios":
        parser.error("The device archive has an unexpected bundle ID")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(args.output, "w", compression=ZIP_DEFLATED, compresslevel=9) as ipa:
        for path in [app.parent, app, *sorted(app.rglob("*"))]:
            name = "Payload" if path == app.parent else "Payload/" + path.relative_to(app.parent).as_posix()
            directory = path.is_dir()
            entry = ZipInfo(name + ("/" if directory else ""))
            entry.create_system = 3
            mode = stat.S_IFDIR | 0o755 if directory else stat.S_IFREG | (0o755 if path == executable else 0o644)
            entry.external_attr = mode << 16
            entry.compress_type = ZIP_DEFLATED
            ipa.writestr(entry, b"" if directory else path.read_bytes())
    print(f"Created unsigned IPA: {args.output}")


if __name__ == "__main__":
    main()
