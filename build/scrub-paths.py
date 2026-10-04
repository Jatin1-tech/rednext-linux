#!/usr/bin/env python3
"""Remove the build user's home path from files in an image tree.

usage: scrub-paths.py USER PATH...

Compiled programs keep source paths (__FILE__, RUNPATH, debug dirs) such as
/home/USER/rn-build/src/foo.c. Every b"/home/USER/" is overwritten in place with a
string of the same length (/usr/src/___/), so offsets inside ELF files stay valid.
Symlinks are never followed. Prints each file it changed.
"""
import os
import stat
import sys

user = sys.argv[1]
old = f"/home/{user}/".encode()
new = b"/usr/src/" + b"_" * (len(old) - 10) + b"/"
assert len(new) == len(old) and len(old) >= 10

changed = 0
for top in sys.argv[2:]:
    for dirpath, dirnames, filenames in os.walk(top):
        for name in filenames:
            p = os.path.join(dirpath, name)
            try:
                st = os.lstat(p)
                if not stat.S_ISREG(st.st_mode):
                    continue
                with open(p, "rb") as f:
                    data = f.read()
            except OSError:
                continue
            if old not in data:
                continue
            with open(p, "r+b") as f:
                f.write(data.replace(old, new))
            os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
            print(p)
            changed += 1
print(f"scrub-paths: {changed} file(s) rewritten", file=sys.stderr)
