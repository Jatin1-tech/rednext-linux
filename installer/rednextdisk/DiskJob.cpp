/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "DiskJob.h"

#include "GlobalStorage.h"
#include "JobQueue.h"
#include "utils/Logger.h"

#include <QJsonDocument>
#include <QProcess>
#include <QTemporaryFile>

#include <stdlib.h>

DiskJob::DiskJob( const QString& engine, const QVariantMap& plan, QObject* parent )
    : Calamares::Job( parent )
    , m_engine( engine )
    , m_plan( plan )
{
}

QString
DiskJob::prettyName() const
{
    return tr( "Prepare the disk" );
}

QString
DiskJob::prettyDescription() const
{
    QStringList lines;
    for ( const QVariant& a : m_plan.value( QStringLiteral( "actions" ) ).toList() )
    {
        lines << a.toMap().value( QStringLiteral( "text" ) ).toString().toHtmlEscaped();
    }
    return lines.join( QStringLiteral( "<br/>" ) );
}

QString
DiskJob::prettyStatusMessage() const
{
    return tr( "Partitioning, formatting and mounting %1" ).arg( m_plan.value( QStringLiteral( "disk" ) ).toString() );
}

Calamares::JobResult
DiskJob::exec()
{
    // the engine re-plans from the original request and refuses if the disk changed
    QVariantMap req = m_plan.value( QStringLiteral( "request" ) ).toMap();
    req.insert( QStringLiteral( "fingerprint" ), m_plan.value( QStringLiteral( "fingerprint" ) ) );

    QTemporaryFile reqFile( QStringLiteral( "/tmp/rednext-disk-XXXXXX.json" ) );
    if ( !reqFile.open() )
    {
        return Calamares::JobResult::error( tr( "Could not write the disk plan." ) );
    }
    reqFile.write( QJsonDocument::fromVariant( req ).toJson() );
    reqFile.flush();

    char tmpl[] = "/tmp/calamares-root-XXXXXX";
    const char* root = mkdtemp( tmpl );
    if ( !root )
    {
        return Calamares::JobResult::error( tr( "Could not create the target mount point." ) );
    }

    emit progress( 0.05 );
    QProcess p;
    p.setProcessChannelMode( QProcess::SeparateChannels );
    p.start( m_engine, { QStringLiteral( "commit" ), reqFile.fileName(), QStringLiteral( "--root" ), QString::fromLocal8Bit( root ) } );
    if ( !p.waitForStarted( 5000 ) )
    {
        return Calamares::JobResult::error( tr( "The disk engine could not be started." ), m_engine );
    }
    QString log;
    while ( !p.waitForFinished( 500 ) )
    {
        if ( p.state() == QProcess::NotRunning )
        {
            break;
        }
        const QString chunk = QString::fromUtf8( p.readAllStandardError() );
        if ( !chunk.isEmpty() )
        {
            log += chunk;
            for ( const QString& l : chunk.split( '\n', Qt::SkipEmptyParts ) )
            {
                cDebug() << "rednext-disk:" << l;
            }
        }
    }
    const QString tail = QString::fromUtf8( p.readAllStandardError() );
    log += tail;
    for ( const QString& l : tail.split( '\n', Qt::SkipEmptyParts ) )
    {
        cDebug() << "rednext-disk:" << l;
    }
    const QVariantMap out = QJsonDocument::fromJson( p.readAllStandardOutput() ).toVariant().toMap();
    if ( p.exitStatus() != QProcess::NormalExit || p.exitCode() != 0 || !out.value( QStringLiteral( "ok" ) ).toBool() )
    {
        QStringList errs;
        for ( const QVariant& e : out.value( QStringLiteral( "errors" ) ).toList() )
        {
            errs << e.toString();
        }
        const QStringList logLines = log.split( '\n', Qt::SkipEmptyParts );
        return Calamares::JobResult::error(
            errs.isEmpty() ? tr( "Setting up the disk failed." ) : errs.join( QStringLiteral( "\n" ) ),
            logLines.mid( qMax( 0, logLines.size() - 25 ) ).join( QStringLiteral( "\n" ) ) );
    }

    auto* gs = Calamares::JobQueue::instance()->globalStorage();
    const QString fw = out.value( QStringLiteral( "firmware" ) ).toString();
    gs->insert( QStringLiteral( "partitions" ), out.value( QStringLiteral( "partitions" ) ) );
    gs->insert( QStringLiteral( "rootMountPoint" ), out.value( QStringLiteral( "rootMountPoint" ) ) );
    gs->insert( QStringLiteral( "mountOptionsList" ), out.value( QStringLiteral( "mountOptionsList" ) ) );
    gs->insert( QStringLiteral( "extraMounts" ), out.value( QStringLiteral( "extraMounts" ) ) );
    gs->insert( QStringLiteral( "firmwareType" ), fw );
    if ( fw == QLatin1String( "efi" ) )
    {
        gs->insert( QStringLiteral( "efiSystemPartition" ), QStringLiteral( "/boot/efi" ) );
    }
    else
    {
        gs->insert( QStringLiteral( "bootLoader" ),
                    QVariantMap { { QStringLiteral( "installPath" ), out.value( QStringLiteral( "disk" ) ) } } );
    }
    gs->insert( QStringLiteral( "partitionChoices" ),
                QVariantMap { { QStringLiteral( "swap" ), out.value( QStringLiteral( "swap" ) ).toString() } } );
    emit progress( 1.0 );
    return Calamares::JobResult::ok();
}
