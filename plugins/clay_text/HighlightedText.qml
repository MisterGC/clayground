// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype HighlightedText
    \inqmlmodule Clayground.Text
    \inherits TextArea
    \brief A TextArea with regular expression highlighting support.

    HighlightedText extends TextArea to provide real-time text highlighting
    based on a regular expression pattern. Useful for search functionality,
    quest logs, or any text that needs visual emphasis on matching patterns.

    Example usage:
    \qml
    import Clayground.Text

    HighlightedText {
        width: 300
        height: 200
        text: "Find the sword and defeat the dragon."
        searchRegEx: "\\b(sword|dragon)\\b"
    }
    \endqml

    \qmlproperty string HighlightedText::searchRegEx
    \brief Regular expression pattern for text to highlight.

    Set this to a regex pattern string. All matching text will be
    visually highlighted. The highlighting updates automatically
    when the pattern or text changes.
*/

import QtQuick
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
