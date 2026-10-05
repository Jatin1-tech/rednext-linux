/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Runs `rednext-disk commit` for the plan accepted on the disk page: partitions,
 * formats and mounts the target, then publishes what the stock Calamares jobs
 * (unpackfs, fstab, bootloader, umount) read from GlobalStorage.
 */
#ifndef REDNEXTDISK_DISKJOB_H
#define REDNEXTDISK_DISKJOB_H

#include "Job.h"

#include <QVariantMap>

class DiskJob : public Calamares::Job
{
    Q_OBJECT
public:
    DiskJob( const QString& engine, const QVariantMap& plan, QObject* parent = nullptr );

    QString prettyName() const override;
    QString prettyDescription() const override;
    QString prettyStatusMessage() const override;
    Calamares::JobResult exec() override;

private:
    QString m_engine;
    QVariantMap m_plan;
};

#endif
