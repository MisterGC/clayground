import QtQuick 2.0

Canvas
{
    id: theCanvas
    anchors.fill: parent

    property real angle: Math.PI / 2
    property alias animDuration: nrAnim.duration
    onAngleChanged: requestPaint()
    Behavior on angle {NumberAnimation {id: nrAnim; duration: 1000; easing.type: Easing.InOutQuad} }

    Timer {
        interval: 3000
        running: true
        repeat: true
        //Component.onCompleted: theLabel.text = Math.round(theAngle.angle) + "° " + theAngle.classifyAngle(theAngle.angle)

        onTriggered: {
            var newAngle = Math.random() * (Math.PI * 2);
            //theAngle.updateAngle(newAngle);
        }
    }

        function updateAngle(newAngle) {
            var delta = Math.abs(newAngle - angle)
            animDuration = (delta / (Math.PI * .1)) * 100
            angle = newAngle
            var newAngleDeg = Math.round(360-(newAngle/(2*Math.PI))*360)
            theLabel.text = newAngleDeg + "° " + classifyAngle(newAngleDeg)
        }
        function classifyAngle(a)
        {
            if (a < 90)
                return "(Spitzer Winkel)"
            else if (a === 90)
                return "(Rechter Winkel)"
            else if (a > 90 && a < 180)
                return "(Stumpfer Winkel)"
            else if (a === 180)
                return "(Gestreckter Winkel)"
            else if (a > 180 && a < 360)
                return "(Überstumpfer Winkel)"
            else
                return "(Vollwinkel)"
        }

    Text {
        id: theLabel
        font.pixelSize: parent.height / 14
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
    }

    MouseArea {
        anchors.fill: parent
        onMouseXChanged: updateAngle()
        onMouseYChanged: updateAngle()
        function updateAngle()
        {
           var vec = Qt.vector2d(mouseX - width/2, mouseY - height/2);
           console.log("x: " + vec.x + " y: " + vec.y)
           var r = vec.length();
           console.log("r: " + r)
           var alpha = Math.acos(vec.x/r);
           if (vec.y < 0) {
               if (x < 0)
                   alpha = Math.PI - (alpha - Math.PI);
               else
                   alpha = (2 * Math.PI) - alpha;
           }

           console.log("angle: " + alpha)
           theAngle.updateAngle(alpha);

        }

    }
    function drawBoard(context, bw, bh, p)
    {
        for (var x = 0; x <= bw; x += 40) {
            context.moveTo(0.5 + x + p, p);
            context.lineTo(0.5 + x + p, bh + p);
        }

        for (var x = 0; x <= bh; x += 40) {
            context.moveTo(p, 0.5 + x + p);
            context.lineTo(bw + p, 0.5 + x + p);
        }
        context.strokeStyle = Qt.rgba(0,0,0,.2)
        context.stroke();
    }

    function drawAngle(ctx, radius, angle, fill, stroke)
    {
        var centreX = width / 2;
        var centreY = height / 2;

        ctx.beginPath();
        ctx.lineWidth = 5
        ctx.fillStyle = Qt.rgba(.5, .5, .5, .4);
        ctx.strokeStyle = Qt.rgba(0, 0, 0,81.);
        ctx.moveTo(centreX, centreY);
        ctx.lineTo(centreX+radius * 1.05, centreY);
        ctx.stroke();

        ctx.beginPath();
        ctx.moveTo(centreX, centreY);
        ctx.arc(centreX, centreY, radius, 0, angle, true);
        if (fill) ctx.fill();
        if (stroke) ctx.stroke();

        ctx.beginPath();
        ctx.strokeStyle = Qt.rgba(0,0,0,1);
        ctx.moveTo(centreX, centreY);
        ctx.lineTo(centreX + Math.cos(angle)*radius*1.05,
                   centreY + Math.sin(angle)*radius*1.05);
        ctx.stroke();
    }


    function drawCircle(ctx, xCenter, yCenter, radius) {
       ctx.beginPath();
       ctx.fillStyle = Qt.rgba(0., 0., 0., 1.);
       ctx.moveTo(xCenter, yCenter);
       ctx.arc(xCenter, yCenter, radius, 0, 2*Math.PI, true);
       ctx.fill();
    }

    onPaint:
    {
        var ctx = getContext("2d");
        ctx.reset();
        drawBoard(ctx, width, height, 0)
        drawAngle(ctx, width / 4, angle, true, false)
        drawAngle(ctx, width / 8, angle, false, true)
        drawCircle(ctx, width/2, height/2, 6)
    }

}
