// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "perfregistry.h"
#include <QDateTime>
#include <QVariantMap>

/*!
    \qmltype PerfRegistry
    \nativetype PerfRegistry
    \inqmlmodule Clayground.Canvas3D
    \brief App-wide singleton for measuring named code sections and event rates.

    PerfRegistry is a lightweight, dependency-free profiling registry meant to be
    dropped into any simulation or render loop and read back by a HUD. It has two
    primitives:

    \list
    \li \b Sections - wrap a block with \l begin / \l end to record how long it
        takes; the registry keeps a rolling average over the last ~60 samples.
    \li \b Counters - call \l tick each time an event happens; the registry
        reports the number of ticks over the last second.
    \endlist

    It is cheap when unused: no timer runs until a section or counter is first
    touched. \l PerfHud appends a \l snapshot of these readings beneath its
    render stats automatically.

    \qml
    import Clayground.Canvas3D

    // in a per-frame handler:
    PerfRegistry.begin("carSim")
    stepSimulation()
    PerfRegistry.end("carSim")

    PerfRegistry.begin("carPack")
    packAndUpload()
    PerfRegistry.end("carPack")
    \endqml

    \sa PerfHud, DynamicInstances3D
*/

PerfRegistry::PerfRegistry(QObject *parent)
    : QObject(parent)
{
    m_clock.start();
}

/*!
    \qmlmethod void PerfRegistry::begin(string name)
    \brief Starts timing the section \a name.
*/
void PerfRegistry::begin(const QString &name)
{
    Section &s = m_sections[name];
    if (s.startNs < 0 && !m_sectionOrder.contains(name))
        m_sectionOrder.append(name);
    s.startNs = m_clock.nsecsElapsed();
}

/*!
    \qmlmethod void PerfRegistry::end(string name)
    \brief Stops timing the section \a name and folds it into the rolling average.
*/
void PerfRegistry::end(const QString &name)
{
    auto it = m_sections.find(name);
    if (it == m_sections.end() || it->startNs < 0)
        return;
    Section &s = *it;
    const double ms = (m_clock.nsecsElapsed() - s.startNs) / 1.0e6;
    s.startNs = -1;
    s.samples.append(ms);
    while (s.samples.size() > kWindow)
        s.samples.removeFirst();
    double sum = 0.0;
    for (double v : s.samples)
        sum += v;
    s.avgMs = s.samples.isEmpty() ? 0.0 : sum / s.samples.size();
}

/*!
    \qmlmethod void PerfRegistry::tick(string name)
    \brief Records one occurrence of the counter \a name.
*/
void PerfRegistry::tick(const QString &name)
{
    Counter &c = m_counters[name];
    if (!m_counterOrder.contains(name))
        m_counterOrder.append(name);
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    c.stamps.append(now);
    while (!c.stamps.isEmpty() && now - c.stamps.first() > 1000)
        c.stamps.removeFirst();
    c.rate = c.stamps.size();
}

/*!
    \qmlmethod list PerfRegistry::snapshot()
    \brief Returns the current section averages and counter rates.

    Each element is a map \c{{ name, kind, avgMs, rate }}: \c kind is
    \c "section" (with \c avgMs set) or \c "counter" (with \c rate set).
*/
QVariantList PerfRegistry::snapshot() const
{
    QVariantList out;
    for (const QString &name : m_sectionOrder) {
        const Section &s = m_sections.value(name);
        QVariantMap m;
        m.insert(QStringLiteral("name"), name);
        m.insert(QStringLiteral("kind"), QStringLiteral("section"));
        m.insert(QStringLiteral("avgMs"), s.avgMs);
        m.insert(QStringLiteral("rate"), 0.0);
        out.append(m);
    }
    for (const QString &name : m_counterOrder) {
        const Counter &c = m_counters.value(name);
        QVariantMap m;
        m.insert(QStringLiteral("name"), name);
        m.insert(QStringLiteral("kind"), QStringLiteral("counter"));
        m.insert(QStringLiteral("avgMs"), 0.0);
        m.insert(QStringLiteral("rate"), c.rate);
        out.append(m);
    }
    return out;
}

/*!
    \qmlmethod void PerfRegistry::reset()
    \brief Clears all recorded sections and counters.
*/
void PerfRegistry::reset()
{
    m_sections.clear();
    m_sectionOrder.clear();
    m_counters.clear();
    m_counterOrder.clear();
}
