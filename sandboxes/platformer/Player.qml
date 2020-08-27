// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Svg 1.0

JnRPlayer
{
    id: thePlayer

    // Game Mechanics Configuration
    energy: 10000

    // Physics Configuration
    maxYVelo: 45
    maxXVelo: 27
    categories: Box.Category2
    collidesWith: Box.Category1 | Box.Category3
    bodyType: Body.Dynamic
    density: 300.

    property alias graphics: visu

    function updateAnimation(){
        let desiredAnim = "stand";

        if (isOnGround && Math.abs(desireX) > 0.)
            desiredAnim = "walk";
        else if (!isOnGround)
            desiredAnim = "jump";

        if (visu.currentSprite !== desiredAnim)
            visu.jumpTo(desiredAnim);
    }

    SvgImageSource {
        id: theSvgSource
        svgPath: "visuals"
        annotationRRGGBB:"000000"
    }

    SpriteSequence {
        id: visu
        parent: thePlayer.parent
        width: thePlayer.width
        z: 99
        height: thePlayer.height
        anchors.centerIn: thePlayer
        interpolate: false
        transform: Rotation {
            origin.x: width * .5 ;
            origin.y: height * .5;
            axis { x: 0; y: 1; z: 0 }
            angle: thePlayer.faceRight ? 0 : 180
        }
        sprites: [
            Sprite {
                name: "walk"
                source: theSvgSource.source(name)
                frameCount: 3
                frameRate: 7
            },
            Sprite {
                name: "jump"
                source: theSvgSource.source(name)
                frameCount: 1
                frameRate: 1
            },
            Sprite {
                name: "stand"
                source: theSvgSource.source(name)
                frameCount: 1
                frameRate: 1
            }
        ]

    }
}
