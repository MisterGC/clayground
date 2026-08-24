// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype LabPanel
    \inqmlmodule Clayground.Lab
    \brief A titled paper panel - the surface every lab HUD is made of.

    Panel fill, quiet border, the theme's radius, a small-caps mono title and
    an optional key tag in the corner. Labs grew a dozen of these by hand;
    one component is what makes two different labs read as one product.

    Children stack in a column and the panel sizes itself around them. For a
    fixed-size panel (a canvas, a chart) set \l width and \l height and anchor
    the content to \l body instead.

    Example usage:
    \qml
    import Clayground.Lab

    LabPanel {
        title: LabLang.t("stats.title")
        tag: "M"                                  // the key that toggles it
        Text { text: "12 roads"; font.family: LabTheme.monoFont }
    }
    \endqml

    \sa LabTheme, HintBar, ScenarioBar
*/
Rectangle {
    id: root

    /*!
        \qmlproperty bool LabPanel::hideOnFocus
        \brief Whether this panel steps out of the way in \l {LabView::focus}
               {focus mode}. True for everything but a flow's own overlay.
    */
    property bool hideOnFocus: true

    // Opacity and enabled, NOT visible. Labs bind `visible` on their own
    // panels all the time - a section that is open, a card with something
    // selected - and assigning it here would be overwritten by every one of
    // them, silently, in exactly the labs that use the component most.
    // Nobody binds opacity on a panel.
    opacity: (LabView.focus && root.hideOnFocus) ? 0 : 1
    enabled: !(LabView.focus && root.hideOnFocus)
    Behavior on opacity { NumberAnimation { duration: 120 } }

    /*!
        \qmlproperty string LabPanel::title
        \brief Heading text (already translated).
    */
    property string title: ""

    /*!
        \qmlproperty string LabPanel::tag
        \brief Key hint shown in the top-right corner, e.g. \c "M".

        Panels that a key toggles say so in the corner - that is how a lab
        teaches its own key map without a manual.
    */
    property string tag: ""

    /*!
        \qmlproperty color LabPanel::accent
        \brief Title colour.
    */
    property color accent: LabTheme.primary

    /*!
        \qmlproperty int LabPanel::padding
        \brief Inset around the content.
    */
    property int padding: LabTheme.px(10)

    /*!
        \qmlproperty int LabPanel::spacing
        \brief Gap between stacked children.
    */
    property int spacing: LabTheme.spaceS

    /*!
        \qmlproperty Item LabPanel::body
        \brief The content area below the header - anchor to it for fixed-size panels.
    */
    readonly property alias body: _body

    /*!
        \qmlproperty list<Item> LabPanel::content
        \brief Stacked children (the default property).
    */
    default property alias content: _col.data

    radius: LabTheme.radius
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth

    implicitWidth: Math.max(_col.width,
                            _title.implicitWidth + _tag.width + LabTheme.spaceL)
                   + 2 * padding
    implicitHeight: _header.height + _col.height + 2 * padding

    Item {
        id: _header
        x: root.padding
        y: root.padding
        width: root.width - 2 * root.padding
        height: root.title !== "" ? _title.implicitHeight + LabTheme.spaceM : 0
        visible: root.title !== ""

        Text {
            id: _title
            width: parent.width - (_tag.visible ? _tag.width + LabTheme.spaceL : 0)
            elide: Text.ElideRight
            text: root.title
            color: root.accent
            font.pixelSize: LabTheme.fontSmall; font.bold: true
            font.letterSpacing: 1.4
            font.family: LabTheme.monoFont
        }
        Text {
            id: _tag
            anchors.right: parent.right
            visible: root.tag !== ""
            text: root.tag
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    Item {
        id: _body
        x: root.padding
        y: root.padding + _header.height
        width: root.width - 2 * root.padding
        height: root.height - _header.height - 2 * root.padding

        Column {
            id: _col
            spacing: root.spacing
        }
    }
}
