# SPDX-License-Identifier: GPL-3.0-or-later
# RedNext disk page: QML UI on top of /usr/libexec/rednext/rednext-disk (the storage engine).
# build-installer.sh copies this directory into calamares/src/modules/ before configuring.
calamares_add_plugin(rednextdisk
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        DiskViewStep.cpp
        DiskJob.cpp
    LINK_PRIVATE_LIBRARIES
        calamaresui
    SHARED_LIB
)
