import QtQuick 2.12
import Box2D 2.0

VisualizedCircleBody
{
    id: thePlayer

    // Visual Configuration
    property bool faceRight: false
    property alias text: annotation.text
    color: "#3fa4c8"
    visible: false

    // Game Mechanics Configuration
    property bool isPlayer: true
    property int energy: 10000
    readonly property int maxEnergy: 10000
    property bool moveLeft: false
    property bool moveRight: false
    onMoveLeftChanged: {updateVelocity(); updateAnimation();}
    onMoveRightChanged:{updateVelocity(); updateAnimation();}

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
        if (isOnGround && (moveLeft || moveRight)) {
            if (theSprite.currentSprite !== "walk")
                theSprite.jumpTo("walk");
        }
        else if (!isOnGround)
            theSprite.jumpTo("jump");
        else
            theSprite.jumpTo("stand");
    }

    function updateVelocity(){
        let newXVelo = 0;
        if (moveLeft) newXVelo = -maxXVelo;
        if (moveRight) newXVelo = maxXVelo;
        linearVelocity.x = newXVelo;

        if (moveLeft) faceRight = false;
        if (moveRight) faceRight = true;
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: updateVelocity()
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
                source: "player_animated.png"
                frameCount: 3
                frameRate: 7
            },
            Sprite {
                name: "jump"
                frameX: 220
                frameY: 230
                frameWidth: 220
                frameHeight: 230
                source: "player_animated.png"
                frameCount: 1
                frameRate: 1
            },
            Sprite {
                name: "stand"
                frameY: 230
                frameWidth: 220
                frameHeight: 230
                source: "player_animated.png"
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

    ScalingText
    {
        id: annotation
        visible: false
        parent: thePlayer.parent
        x: thePlayer.x + thePlayer.width/2 - width/2
        y: thePlayer.y - height * 1.1
        z: 99
        text: "(" + thePlayer.moveLeft + "," + thePlayer.moveRight + ")"
        color: "#3fa4c8"
        pixelPerUnit: thePlayer.pixelPerUnit
        fontSizeWu: 0.3
    }
}
