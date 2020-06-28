// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.5

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
           Text {text: caption}
           Text {text: time}
           Text {text: diff}
        }
    }

    function processEntry(caption, seconds) {
        // TODO Calc. diff based on results of prev. session
        let entry = {"caption": caption, "time": seconds, "diff": 0};
        theScores.append(entry);
    }

    function update() {
        theScores.clear();
        let results = db.results;
        console.log("resup: " + JSON.stringify(results));
        for (let k of results.keys())
            processEntry(k, results.get(k));
    }
}
