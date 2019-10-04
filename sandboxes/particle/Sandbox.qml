/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.5
import QtQuick.Particles 2.0

Item {
    id: root
    anchors.fill: parent
    Rectangle {
    color: "black"
    anchors.centerIn: parent
    width: 100
    height: 100
    ParticleSystem { id: particleSystem; running: true }
    Emitter {
        id: emitter
        width: 6*parent.width
        height: width
        anchors.centerIn: parent
        system: particleSystem
        emitRate: 80
        lifeSpan: 500
        lifeSpanVariation: 50
        velocity: TargetDirection { targetX: emitter.width/2; targetY: emitter.height/2; magnitude: 200;}
    }
    ItemParticle {
        system: particleSystem
        delegate: Rectangle {
            width: root.width/20 + Math.random() * root.width/20
            height: width
            color: "grey"
        }
    }
    }
}
