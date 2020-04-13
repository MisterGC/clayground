// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0

JnRPlayer
{
    id: thePlayer

    // Graphics Configuration
    property string spriteSource: "" 

    // Game Mechanics Configuration
    energy: 10000

    // Physics Configuration
    maxYVelo: 45
    maxXVelo: 27
    categories: Box.Category2
    collidesWith: Box.Category1 | Box.Category3
    bodyType: Body.Dynamic
    density: 300.

    function updateAnimation(){
        let desiredAnim = "stand";

        if (isOnGround && Math.abs(desireX) > 0.)
            desiredAnim = "walk";
        else if (!isOnGround)
            desiredAnim = "jump";

        if (theSprite.currentSprite !== desiredAnim)
            theSprite.jumpTo(desiredAnim);
    }

    SpriteSequence {
        id: theSprite
        parent: thePlayer.parent
        width: thePlayer.width
        height: thePlayer.height * 1.2
        anchors.horizontalCenter: thePlayer.horizontalCenter
        anchors.verticalCenter: thePlayer.verticalCenter
        anchors.verticalCenterOffset: -0.1 * thePlayer.height
        z: 99
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
                frameWidth: 220
                frameHeight: 230
                source: thePlayer.spriteSource
                frameCount: 3
                frameRate: 7
            },
            Sprite {
                name: "jump"
                frameX: 220
                frameY: 230
                frameWidth: 220
                frameHeight: 230
                source: thePlayer.spriteSource
                frameCount: 1
                frameRate: 1
            },
            Sprite {
                name: "stand"
                frameY: 230
                frameWidth: 220
                frameHeight: 230
                source: thePlayer.spriteSource
                frameCount: 1
                frameRate: 1
            }
        ]

    }
}
