// (c) Clayground Contributors - MIT License, see "LICENSE" file

/**
 * Responsible for loading specific scenes in a given world.
 * It supports both 2D and 3D worlds.
 */
SceneLoaderBase
{
    function _onBeginSpecifics(widthWu, heightWu) {
        world.xWuMax = widthWu;
        world.zWuMax = heightWu;
    }

    onRectangle: (id, x, y, width, height, description) => {
                    x = x + (.5 * width)
                    const z = (world.zWuMax - y) + (.5 * height)

                    let cfg = _fetchBuilderCfg(description);
                    if (cfg)
                    {
                        let comp = fetchComp(cfg);
                        let inc = comp.incubateObject(world.root,
                            {
                                "position.x": x,
                                "position.z": z,
                                "dimensions.x": width,
                                "dimensions.z": height,
                            });
                        onIncubationInitiated(inc, _currentGroupId(), cfg);
                        return;
                    }

                    world.rectangleLoaded(id, _currentGroupId(), x, y, width, height, description);
                }

    onPolygon: (id, points, description) => {console.log("Not yet supported.");}
    onPolyline: (id, points, description) => {console.log("Not yet supported.");}
    onCircle: (id, x, y, radius, description) => {console.log("Not yet supported.");}
}
