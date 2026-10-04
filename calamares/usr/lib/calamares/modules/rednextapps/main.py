#!/usr/bin/env python3
# RedNext: download and install the optional apps ticked on the "Extra apps" page
# (packagechooser@apps). A failed download is logged and skipped; it never fails
# the whole installation.
import subprocess

import libcalamares

HELPER = "/usr/libexec/rednext/install-optional-app"
NAMES = {"blender": "Blender", "spotify": "Spotify", "intellij": "IntelliJ IDEA",
         "pycharm": "PyCharm", "rider": "Rider"}
_status = "Installing extra apps"


def pretty_name():
    return "Installing extra apps"


def pretty_status_message():
    return _status


def run():
    global _status
    gs = libcalamares.globalstorage
    chosen = gs.value("packagechooser_apps") or ""
    apps = [a for a in str(chosen).split(",") if a in NAMES]
    if not apps:
        libcalamares.utils.debug("rednextapps: nothing selected")
        return None
    root = gs.value("rootMountPoint")
    failed = []
    for i, app in enumerate(apps):
        _status = "Downloading and installing {} ({}/{})".format(NAMES[app], i + 1, len(apps))
        libcalamares.job.setprogress(i / len(apps))
        libcalamares.utils.debug("rednextapps: " + _status)
        r = subprocess.run([HELPER, app, root], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in r.stdout.splitlines():
            libcalamares.utils.debug("rednextapps: " + line)
        if r.returncode != 0:
            failed.append(NAMES[app])
    libcalamares.job.setprogress(1.0)
    if failed:
        libcalamares.utils.warning("rednextapps: could not install " + ", ".join(failed))
        gs.insert("rednextapps_failed", ", ".join(failed))
    return None
