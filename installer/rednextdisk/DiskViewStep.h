/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * RedNext disk page. The page itself is QML (branding/rednext/rednext-disk.qml);
 * this step only bridges it to the storage engine (rednext-disk probe/plan) and
 * hands the accepted plan to DiskJob, which runs `rednext-disk commit`.
 */
#ifndef REDNEXTDISK_DISKVIEWSTEP_H
#define REDNEXTDISK_DISKVIEWSTEP_H

#include "DllMacro.h"
#include "utils/PluginFactory.h"
#include "viewpages/QmlViewStep.h"

#include <QObject>
#include <QString>
#include <QVariantMap>

class DiskConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY( bool ready READ ready NOTIFY readyChanged )
    Q_PROPERTY( QString summary READ summary NOTIFY readyChanged )

public:
    explicit DiskConfig( QObject* parent = nullptr );

    /// JSON text from `rednext-disk probe`
    Q_INVOKABLE QString probe();
    /// JSON text from `rednext-disk plan` for the given request JSON
    Q_INVOKABLE QString plan( const QString& request );
    /// The page shows @p planJson; Next is enabled when it is valid
    Q_INVOKABLE void accept( const QString& planJson );
    Q_INVOKABLE void clear();

    bool ready() const { return m_ready; }
    QString summary() const;
    QVariantMap acceptedPlan() const { return m_plan; }
    QString engine() const { return m_engine; }
    void setEngine( const QString& e ) { m_engine = e; }

signals:
    void readyChanged( bool ready );

private:
    QString run( const QStringList& args, const QByteArray& input );

    QString m_engine = QStringLiteral( "/usr/libexec/rednext/rednext-disk" );
    QVariantMap m_plan;
    bool m_ready = false;
};

class PLUGINDLLEXPORT DiskViewStep : public Calamares::QmlViewStep
{
    Q_OBJECT

public:
    explicit DiskViewStep( QObject* parent = nullptr );
    ~DiskViewStep() override;

    QString prettyName() const override;
    QString prettyStatus() const override;

    bool isNextEnabled() const override;
    bool isBackEnabled() const override;
    bool isAtBeginning() const override;
    bool isAtEnd() const override;

    Calamares::JobList jobs() const override;
    void onLeave() override;
    void setConfigurationMap( const QVariantMap& configurationMap ) override;

    QObject* getConfig() override { return m_config; }

private:
    DiskConfig* m_config;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION( DiskViewStepFactory )

#endif
