// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype SceneLoader3d
    \inqmlmodule Clayground.World
    \brief Scene loader specialized for 3D worlds.

    SceneLoader3d extends SceneLoaderBase with 3D-specific handling that
    converts SVG rectangles to 3D objects for ClayWorld3d. The SVG Y coordinate
    maps to Z in 3D, and width/height become width/depth.

    \sa SceneLoaderBase, ClayWorld3d
*/
SceneLoaderBase
{
    function _onBeginSpecifics(widthWu, heightWu) {
        world.xWuMax = widthWu;
        world.zWuMax = heightWu;
    }

    onRectangle: (id, x, y, width, height, fillColor, strokeColor, description) => {
                    x = x + (.5 * width)
                    const z = (world.zWuMax - y) + (.5 * height)

                    let cfg = _fetchBuilderCfg(fillColor, strokeColor, description);
                    if (cfg)
                    {
                        let comp = fetchComp(cfg);
                        let inc = comp.incubateObject(world.root,
                            {
                                "position.x": x,
                                "position.z": z,
                                "width": width,
                                "depth": height,
                            });
                        onIncubationInitiated(inc, _currentGroupId(), cfg);
                        return;
                    }

                    world.rectangleLoaded(id, _currentGroupId(), x, y, width, height, description);
                }

    onPolygon: (id, points, fillColor, strokeColor, description) => {console.log("Not yet supported.");}
    onPolyline: (id, points, fillColor, strokeColor, description) => {console.log("Not yet supported.");}
    onCircle: (id, x, y, radius, fillColor, strokeColor, description) => {console.log("Not yet supported.");}
}
