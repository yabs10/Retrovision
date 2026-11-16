#!/usr/bin/env python3
# One-step build for Retrovision: regenerate textures, run the offline Lua test,
# mirror the addon into the WoW Forever AddOns folder and rebuild the Desktop zip.
#   python3 build.py              everything
#   python3 build.py --no-install textures + test only
#   python3 build.py --no-media   skip texture regeneration
import argparse, os, shutil, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "Retrovision")
DEST = "/home/yabs/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Retrovision"
ZIP = "/home/yabs/Desktop/Retrovision.zip"
MEDIA_SCRIPTS = ("make_media.py", "make_monitor.py", "make_icon.py")
SKIP = {"__pycache__", ".DS_Store"}


def die(msg):
    print("BUILD FAILED: " + msg)
    sys.exit(1)


def run(cmd):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def source_files():
    out = []
    for dirpath, dirs, files in os.walk(SRC):
        dirs[:] = sorted(d for d in dirs if d not in SKIP)
        for f in sorted(files):
            if f not in SKIP:
                out.append(os.path.relpath(os.path.join(dirpath, f), SRC))
    return out


def mirror(files):
    dest = os.path.normpath(DEST)
    if not dest.endswith(os.sep + os.path.join("AddOns", "Retrovision")):
        die("refusing to install: target does not end in /AddOns/Retrovision: " + dest)
    if not os.path.isdir(os.path.dirname(dest)):
        die("AddOns folder not found: " + os.path.dirname(dest))
    if os.path.islink(dest):
        die("refusing to install: target is a symlink: " + dest)
    copied = removed = 0
    keep = set(files)
    for rel in files:
        s, d = os.path.join(SRC, rel), os.path.join(dest, rel)
        os.makedirs(os.path.dirname(d), exist_ok=True)
        if not os.path.exists(d) or not filecmp_same(s, d):
            shutil.copy2(s, d); copied += 1
    # remove anything in the installed folder that is no longer in source (only inside dest)
    for dirpath, dirs, fnames in os.walk(dest, topdown=False):
        for f in fnames:
            p = os.path.join(dirpath, f)
            if os.path.relpath(p, dest) not in keep:
                os.remove(p); removed += 1
        for dname in dirs:
            p = os.path.join(dirpath, dname)
            if os.path.islink(p):
                os.remove(p); removed += 1
            elif not os.listdir(p):
                os.rmdir(p)
    return dest, copied, removed


def filecmp_same(a, b):
    import filecmp
    return filecmp.cmp(a, b, shallow=False)


def make_zip(files):
    tmp = ZIP + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files:
            z.write(os.path.join(SRC, rel), os.path.join("Retrovision", rel))
    os.replace(tmp, ZIP)
    return os.path.getsize(ZIP)


def main():
    ap = argparse.ArgumentParser(description="Build Retrovision")
    ap.add_argument("--no-install", action="store_true", help="textures + test only (no install, no zip)")
    ap.add_argument("--no-media", action="store_true", help="skip texture regeneration")
    args = ap.parse_args()
    summary = []

    if args.no_media:
        summary.append("textures: skipped")
    else:
        for script in MEDIA_SCRIPTS:
            code, out = run([sys.executable, script])
            if code != 0:
                print(out); die(script + " failed")
        summary.append("textures: regenerated (%d files in media/)" % len(os.listdir(os.path.join(SRC, "media"))))

    if not os.path.exists(os.path.join(ROOT, "test.lua")):
        summary.append("test.lua: not present, skipped")
    else:
        if not shutil.which("lua5.1"):
            die("lua5.1 not found")
        code, out = run(["lua5.1", "test.lua"])
        if code != 0 or not out.rstrip().endswith("ALL OK"):
            print(out.rstrip()[-3000:])
            die("test.lua did not end in ALL OK (exit %d)" % code)
        summary.append("test.lua: ALL OK")

    if args.no_install:
        summary.append("install + zip: skipped (--no-install)")
    else:
        files = source_files()
        dest, copied, removed = mirror(files)
        summary.append("installed: %d files (%d updated, %d removed) -> %s" % (len(files), copied, removed, dest))
        size = make_zip(files)
        summary.append("zip: %s (%d KB)" % (ZIP, size // 1024))

    print("Retrovision build OK")
    for line in summary:
        print("  " + line)


if __name__ == "__main__":
    main()
