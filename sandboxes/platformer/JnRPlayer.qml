// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Box2D 2.0
import Clayground.Physics 1.0

VisualizedBoxBody {
    id: theImage

    // Visual Configuration
    property bool faceRight: true

    // Game Mechanics Configuration
    property bool isPlayer: true
    property int energy: 10000
    readonly property bool isAlive: energy > 0
    opacity: 0

    // Physics Configuration
    fixedRotation: true
    bodyType: Body.Dynamic
    bullet: true
    friction: isOnGround ? 10. : .01
    restitution: 0.
    property real desireX: 0.0
    onDesireXChanged: {updateVelocity(); updateAnimation();}
    property real maxYVelo: 0
    property real maxXVelo: 0

    function updateAnimation(){
        // Nothing - overwrite in specific impl
    }

    function updateVelocity(){
        linearVelocity.x = desireX * maxXVelo;
        if (Math.abs(desireX) > .1)
            faceRight = (desireX > 0)
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: { updateVelocity(); updateAnimation(); }
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

