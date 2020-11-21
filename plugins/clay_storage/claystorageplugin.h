// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#ifndef CLAYGROUND_STORAGE_PLUGIN
#define CLAYGROUND_STORAGE_PLUGIN
#include <QQmlExtensionPlugin>

class ClayStoragePlugin: public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "clayground.storageplugin")

public:
    ClayStoragePlugin();
    
    void registerTypes(const char* uri) override;
};
#endif

