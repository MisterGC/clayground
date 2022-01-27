// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

ListView
{
    property TrainingDb resultStorage: null
    delegate: scoreEntry
    model: theScores

    ListModel { id: theScores }
    Component {
        id: scoreEntry
        Row {
           spacing: 5
           Text {text: caption; font.family: "Monospace"}
           Text {text: time; font.family: "Monospace"}
           Text {text: diff; font.family: "Monospace"}
        }
    }

    function processEntry(caption, seconds) {
        let diff = 0;
        if (resultStorage.oldResults.has(caption))
            diff = seconds - resultStorage.oldResults.get(caption);
        diff = diff.toFixed(2);
        let entry = {"caption": caption.padEnd(25, ' '),
                     "time": seconds.padEnd(5, ' '),
                     "diff": (diff >= 0 ? "+" : "") + diff};
        theScores.append(entry);
    }

    function update() {
        theScores.clear();
        let results = db.results;
        for (let k of results.keys())
            processEntry(k, results.get(k));
    }

    signal nextRoundRequested();
    Button {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        text: "Next Round"
        onClicked: parent.nextRoundRequested()
    }
}
