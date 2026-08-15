// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include "hotreloadcontainer.h"
#include <clayscenehost.h>

// Presents the dojo's HotReloadContainer as a ClayScene::Host, which is all
// the scene layer ever sees of the widget world. The generation counter is
// owned here rather than by the container: the inspector is what knows when a
// load actually succeeded.
class LoaderSceneHost : public ClayScene::Host
{
public:
    explicit LoaderSceneHost(HotReloadContainer* container)
        : m_container(container) {}

    QQuickItem* rootObject() const override
    {
        return m_container ? m_container->rootObject() : nullptr;
    }

    int generation() const override { return m_generation; }
    void setGeneration(int generation) { m_generation = generation; }

private:
    HotReloadContainer* m_container = nullptr;
    int m_generation = 0;
};
