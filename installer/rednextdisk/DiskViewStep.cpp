/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "DiskViewStep.h"
#include "DiskJob.h"

#include "GlobalStorage.h"
#include "JobQueue.h"
#include "utils/Logger.h"
#include "utils/Variant.h"

#include <QDir>
#include <QJsonDocument>
#include <QProcess>

CALAMARES_PLUGIN_FACTORY_DEFINITION( DiskViewStepFactory, registerPlugin< DiskViewStep >(); )

static bool
isEfi()
{
    return QDir( QStringLiteral( "/sys/firmware/efi" ) ).exists();
}

DiskConfig::DiskConfig( QObject* parent )
    : QObject( parent )
{
}

QString
DiskConfig::run( const QStringList& args, const QByteArray& input )
{
    QProcess p;
    p.start( m_engine, args );
    if ( !p.waitForStarted( 5000 ) )
    {
        cError() << "rednext-disk: cannot start" << m_engine;
        return QStringLiteral( R"({"ok": false, "fatal": true, "errors": ["The disk engine (%1) is missing."]})" )
            .arg( m_engine );
    }
    if ( !input.isEmpty() )
    {
        p.write( input );
    }
    p.closeWriteChannel();
    p.waitForFinished( 60000 );
    const QString err = QString::fromUtf8( p.readAllStandardError() ).trimmed();
    if ( !err.isEmpty() )
    {
        cDebug() << "rednext-disk" << args.value( 0 ) << "stderr:" << err;
    }
    return QString::fromUtf8( p.readAllStandardOutput() );
}

QString
DiskConfig::probe()
{
    return run( { QStringLiteral( "probe" ) }, QByteArray() );
}

QString
DiskConfig::plan( const QString& request )
{
    return run( { QStringLiteral( "plan" ), QStringLiteral( "-" ) }, request.toUtf8() );
}

void
DiskConfig::accept( const QString& planJson )
{
    const QVariantMap p = QJsonDocument::fromJson( planJson.toUtf8() ).toVariant().toMap();
    const bool ok = p.value( QStringLiteral( "ok" ) ).toBool() && !p.value( QStringLiteral( "fatal" ) ).toBool();
    m_plan = ok ? p : QVariantMap();
    if ( ok != m_ready || ok )
    {
        m_ready = ok;
        emit readyChanged( m_ready );
    }
}

void
DiskConfig::clear()
{
    m_plan.clear();
    m_ready = false;
    emit readyChanged( false );
}

QString
DiskConfig::summary() const
{
    if ( !m_ready )
    {
        return QString();
    }
    QStringList lines;
    for ( const QVariant& a : m_plan.value( QStringLiteral( "actions" ) ).toList() )
    {
        const QVariantMap m = a.toMap();
        QString t = m.value( QStringLiteral( "text" ) ).toString().toHtmlEscaped();
        const QString kind = m.value( QStringLiteral( "kind" ) ).toString();
        if ( kind == QLatin1String( "destroy" ) || kind == QLatin1String( "delete" )
             || kind == QLatin1String( "format" ) )
        {
            t = QStringLiteral( "<b style=\"color:#F0A0AA\">%1</b>" ).arg( t );
        }
        lines << t;
    }
    return lines.join( QStringLiteral( "<br/>" ) );
}

DiskViewStep::DiskViewStep( QObject* parent )
    : Calamares::QmlViewStep( parent )
    , m_config( new DiskConfig( this ) )
{
    connect( m_config, &DiskConfig::readyChanged, this, &DiskViewStep::nextStatusChanged );
    // the bootloader job and the QML page both need to know this from the start
    Calamares::JobQueue::instance()->globalStorage()->insert(
        QStringLiteral( "firmwareType" ), isEfi() ? QStringLiteral( "efi" ) : QStringLiteral( "bios" ) );
}

DiskViewStep::~DiskViewStep() {}

QString
DiskViewStep::prettyName() const
{
    return tr( "Disk" );
}

QString
DiskViewStep::prettyStatus() const
{
    return m_config->summary();
}

bool
DiskViewStep::isNextEnabled() const
{
    return m_config->ready();
}

bool
DiskViewStep::isBackEnabled() const
{
    return true;
}

bool
DiskViewStep::isAtBeginning() const
{
    return true;
}

bool
DiskViewStep::isAtEnd() const
{
    return true;
}

Calamares::JobList
DiskViewStep::jobs() const
{
    if ( !m_config->ready() )
    {
        return {};
    }
    return { Calamares::job_ptr( new DiskJob( m_config->engine(), m_config->acceptedPlan() ) ) };
}

void
DiskViewStep::onLeave()
{
    Calamares::QmlViewStep::onLeave();
    // the summary page reads prettyStatus(); the plan stays as accepted
}

void
DiskViewStep::setConfigurationMap( const QVariantMap& configurationMap )
{
    const QString engine = Calamares::getString( configurationMap, QStringLiteral( "engine" ) );
    if ( !engine.isEmpty() )
    {
        m_config->setEngine( engine );
    }
    Calamares::QmlViewStep::setConfigurationMap( configurationMap );
}
