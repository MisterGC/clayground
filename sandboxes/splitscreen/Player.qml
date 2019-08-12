import QtQuick 2.12
import Box2D 2.0

VisualizedCircleBody
{
    id: thePlayer

    // Visual Configuration
    property bool faceRight: true
    color: "#3fa4c8"
    visible: false
    property alias sprite: theSprite
    property alias currentSprite: theSprite.currentSprite
    property alias spriteSheet: theSprite.spriteSheet

    // Game Mechanics Configuration
    property bool isPlayer: true
    property int energy: 10000
    readonly property int maxEnergy: 10000
    property real desireX: 0.0
    onDesireXChanged: {updateVelocity(); updateAnimation();}

    // Physics Configuration
    property real maxYVelo: 8
    property real maxXVelo: 8
    categories: Box.Category2
    collidesWith: Box.Category1
    bodyType: Body.Dynamic
    bullet: true
    fixedRotation: Math.abs(linearVelocity.x) < 0.3 || !isOnGround
    density: 300.
    friction: isOnGround ? 10. : .01
    restitution: 0.

    function updateAnimation(){
        let desiredAnim = "stand";

        if (isOnGround && Math.abs(desireX) > 0.)
            desiredAnim = "walk";
        else if (!isOnGround)
            desiredAnim = "jump";

        if (theSprite.currentSprite !== desiredAnim)
            theSprite.jumpTo(desiredAnim);
    }

    function updateVelocity(){
        linearVelocity.x = desireX * maxXVelo;
        if (Math.abs(desireX) > .1)
            faceRight = (desireX > 0)
    }
    Timer {
        interval: 50
        repeat: true
        running: active
        onTriggered: { updateVelocity(); updateAnimation(); }
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
        property string spriteSheet: "player_animated.png"
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
                source: theSprite.spriteSheet
                frameCount: 3
                frameRate: 7
            },
            Sprite {
                name: "jump"
                frameX: 220
                frameY: 230
                frameWidth: 220
                frameHeight: 230
                source: theSprite.spriteSheet
                frameCount: 1
                frameRate: 1
            },
            Sprite {
                name: "stand"
                frameY: 230
                frameWidth: 220
                frameHeight: 230
                source: theSprite.spriteSheet
                frameCount: 1
                frameRate: 1
            }
        ]

    }

    property bool isOnGround: !(fallDownTimer.running) && Math.abs(linearVelocity.y) < 0.01
    onIsOnGroundChanged: updateAnimation();
    function jump() { if (isOnGround){ reJumpTimer.restart() } }
    Timer {
        interval: 10
        running: reJumpTimer.running
        repeat: true
        onTriggered: linearVelocity.y = -1 * maxYVelo
    }
    Timer { id: reJumpTimer; interval: 300; onTriggered: fallDownTimer.restart() }
    Timer { id: fallDownTimer; interval: 200; }
}
