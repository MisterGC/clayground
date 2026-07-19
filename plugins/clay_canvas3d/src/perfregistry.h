// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef PERFREGISTRY_H
#define PERFREGISTRY_H

#include <QObject>
#include <QQmlEngine>
#include <QElapsedTimer>
#include <QHash>
#include <QList>
#include <QString>
#include <QVariantList>

// Dependency-free, app-wide performance registry. begin()/end() measure named
// code sections (rolling average over ~60 samples); tick() counts named events
// (per-second rate). snapshot() returns the current readings for a HUD. Cheap
// when unused - nothing runs until a section or counter is first touched.
// Exposed to QML as the singleton PerfRegistry.
class PerfRegistry : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(PerfRegistry)
    QML_SINGLETON

public:
    explicit PerfRegistry(QObject *parent = nullptr);

    // Start timing the named section. Nesting the same name is not supported;
    // the most recent begin() wins.
    Q_INVOKABLE void begin(const QString &name);

    // Stop timing the named section and fold the elapsed time into its rolling
    // average. A matching begin() must have been called.
    Q_INVOKABLE void end(const QString &name);

    // Record one occurrence of the named counter (rate averaged over 1 s).
    Q_INVOKABLE void tick(const QString &name);

    // Current readings: a list of { name, kind, avgMs, rate } maps. Section rows
    // carry avgMs (rate 0); counter rows carry rate (avgMs 0).
    Q_INVOKABLE QVariantList snapshot() const;

    // Drop all sections and counters.
    Q_INVOKABLE void reset();

private:
    struct Section {
        qint64 startNs = -1;
        QList<double> samples;  // rolling window of durations (ms)
        double avgMs = 0.0;
    };
    struct Counter {
        QList<qint64> stamps;   // event timestamps (ms), last 1 s
        double rate = 0.0;
    };

    static constexpr int kWindow = 60;

    QElapsedTimer m_clock;
    QHash<QString, Section> m_sections;
    QList<QString> m_sectionOrder;
    QHash<QString, Counter> m_counters;
    QList<QString> m_counterOrder;
};

#endif // PERFREGISTRY_H
