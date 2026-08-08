// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton
import QtQuick

/*!
    \qmltype LabPrefs
    \inqmlmodule Clayground.Lab
    \brief The handful of settings that must outlive a reload, and where they go.

    Theme, language and UI scale are not lab state - they are facts about the
    person and the screen. Losing them on every reload is what made the scale
    knob feel broken before it existed: you set it, the loader restarted, and
    it was small again.

    Backed by \c Clayground.Storage when that module is present and by plain
    memory when it is not, so a sandbox that never links the storage plugin
    still runs and still switches themes - it just forgets on exit. Nothing
    here is ever required for a lab to work.

    Keys in use by the kernel:

    \table
    \header \li Key \li Meaning
    \row \li \c ui.theme \li \c "light" or \c "dark" (\l LabTheme::mode)
    \row \li \c ui.scale \li the \l LabTheme::uiScale factor
    \row \li \c ui.lang  \li the \l LabLang::lang code
    \endtable

    A lab may store its own under any other key; prefix them with the lab's
    slug so two labs sharing the store cannot collide.

    \section2 Where the store lives

    Nowhere in QML: the store is a QML LocalStorage database, so it lands in
    whatever directory the host gave its engine. The dojo points that at
    \c ~/.clayground - the person's real settings - and a headless host that
    should not write there points it somewhere throwaway by setting
    \c CLAY_STORAGE_DIR before it builds its engine. \c clayrender does that
    by default (\c {--prefs isolated}), which is why a scripted
    \c {--eval 'LabTheme.mode="dark"'} cannot leave the next dojo session
    dark, and why a render always starts from the defaults unless it was run
    with \c {--prefs user}.

    \sa LabTheme, LabLang, ScaleSwitch
*/
QtObject {
    id: _prefs

    /*!
        \qmlproperty bool LabPrefs::persistent
        \readonly
        \brief True when a backing store was found; false means memory only.
    */
    readonly property bool persistent: _store !== null

    /*!
        \qmlproperty string LabPrefs::storeName
        \brief Database name. One store for all labs, so the settings are the
        person's rather than the lab's.
    */
    property string storeName: "clayground-lab-prefs"

    // The store is built on first use, never at singleton creation: touching
    // LocalStorage costs a file open, and a lab that reads no preference
    // should not pay for one. `_tried` keeps a failure from being retried on
    // every get().
    property bool _tried: false
    property var _store: null
    property var _memory: ({})

    function _ensure() {
        if (_tried) return _store
        _tried = true
        // Deliberately created dynamically rather than declared: declaring it
        // would make Clayground.Lab hard-depend on Clayground.Storage, and a
        // kernel that cannot load because an optional convenience is missing
        // is a worse bargain than a kernel that forgets the theme.
        try {
            _store = Qt.createQmlObject(
                'import QtQuick; import Clayground.Storage;'
                + ' KeyValueStore { name: "' + storeName + '" }',
                _prefs, "LabPrefs.store")
        } catch (e) {
            _store = null
        }
        return _store
    }

    /*!
        \qmlmethod string LabPrefs::get(string key, var fallback)
        \brief The stored value, or \a fallback when there is none.

        Always a string (or the fallback as given) - callers coerce, because
        the store is a text store and pretending otherwise hides the moment a
        number arrives back as \c "1.3".
    */
    function get(key, fallback) {
        const s = _ensure()
        if (!s) return _memory[key] !== undefined ? _memory[key] : fallback
        try {
            return s.get(key, fallback)
        } catch (e) {
            return fallback
        }
    }

    /*!
        \qmlmethod void LabPrefs::set(string key, var value)
        \brief Stores \a value under \a key, silently doing nothing if it cannot.
    */
    function set(key, value) {
        _memory[key] = String(value)
        const s = _ensure()
        if (!s) return
        try {
            s.set(key, String(value))
        } catch (e) {
            // a read-only or unavailable store must never break a lab
        }
    }

    /*! \qmlmethod void LabPrefs::forget(string key) \brief Drops a stored value. */
    function forget(key) {
        delete _memory[key]
        const s = _ensure()
        if (!s) return
        try { s.remove(key) } catch (e) { }
    }
}
