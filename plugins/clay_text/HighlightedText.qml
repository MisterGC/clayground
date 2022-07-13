// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick 2.0
import QtQuick.Controls
import Clayground.Text

TextArea {
    id: _textArea
    color: "white"
    textFormat: TextEdit.MarkdownText
    wrapMode: TextEdit.WordWrap
    property alias searchRegEx: _highlighter.search
    TextHighlighter {
        id: _highlighter
        search: regExInput.text
        document: _textArea.textDocument
        onSearchChanged: rehighlight()
    }
}
