import QtQuick 6.8
import QtQuick.Controls 6.8

Item {
    property int currentUserID: userModel.lastIndex
    property int userNameRole: Qt.UserRole + 1
    property int userRealNameRole: Qt.UserRole + 2
    property var user: userModel.data(
        userModel.index(currentUserID, 0),
        userNameRole
    )
    property var realName: userModel.data(
        userModel.index(currentUserID, 0),
        userRealNameRole
    )

    property alias font: inner.font
    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Tab:
            currentUserID = (currentUserID + 1) % userModel.count;
            break;
        case Qt.Key_Backtab:
            currentUserID = (currentUserID - 1 + userModel.count) % userModel.count;
            break;
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 15

        // User icon
        Rectangle {
            width: 40
            height: 40
            radius: 20
            color: "transparent"
            border.color: "white"
            border.width: 2

            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "👤"
                font.pixelSize: 24
                color: "white"
                anchors.centerIn: parent
            }
        }

        Text {
            id: inner
            renderType: Text.QtRendering
            color: "white"
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            text: realName ? realName : user
            anchors.verticalCenter: parent.verticalCenter

            font {
                family: primaryFont.name
                pointSize: config.fontSize * 1.2
                bold: true
            }
        }
    }

}
