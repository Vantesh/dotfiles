pragma ComponentBehavior

import QtQuick
import QtQuick.Controls
import QtCore
import Qt.labs.folderlistmodel
import Quickshell.Io
import qs.Common
import qs.Widgets

DankModal {
    id: fileBrowserModal
    objectName: "fileBrowserModal"
    allowStacking: true

    signal fileSelected(string path)

    property string homeDir: StandardPaths.writableLocation(
                                 StandardPaths.HomeLocation)
    property string currentPath: ""
    property var fileExtensions: ["*.*"]
    property string browserTitle: "Select File"
    property string browserIcon: "folder_open"
    property string browserType: "generic" // "wallpaper" or "profile" for last path memory

    FolderListModel {
        id: folderModel
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        nameFilters: fileExtensions
        showFiles: true
        showDirs: true
        folder: currentPath ? "file://" + currentPath : "file://" + homeDir
    }

    function isImageFile(fileName) {
        if (!fileName)
            return false
        var ext = fileName.toLowerCase().split('.').pop()
        return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)
    }

    function getLastPath() {
        var lastPath = ""
        if (browserType === "wallpaper") {
            lastPath = SessionData.wallpaperLastPath
        } else if (browserType === "profile") {
            lastPath = SessionData.profileLastPath
        }

        if (lastPath && lastPath !== "") {
            return lastPath
        }
        return homeDir
    }

    function saveLastPath(path) {
        if (browserType === "wallpaper") {
            SessionData.setWallpaperLastPath(path)
        } else if (browserType === "profile") {
            SessionData.setProfileLastPath(path)
        }
    }

    Component.onCompleted: {
        currentPath = getLastPath()
    }

    width: 800
    height: 600
    enableShadow: true
    visible: false

    onBackgroundClicked: close()

    onVisibleChanged: {
        if (visible) {
            var startPath = getLastPath()
            currentPath = startPath
        }
    }

    onCurrentPathChanged: {

    }

    function navigateUp() {
        var path = currentPath

        if (path === homeDir) {
            return
        }

        var lastSlash = path.lastIndexOf('/')
        if (lastSlash > 0) {
            var newPath = path.substring(0, lastSlash)
            if (newPath.length < homeDir.length) {
                currentPath = homeDir
                saveLastPath(homeDir)
            } else {
                currentPath = newPath
                saveLastPath(newPath)
            }
        }
    }

    function navigateTo(path) {
        currentPath = path
        saveLastPath(path) // Save the path when navigating
    }

    content: Component {
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: 40

                Row {
                    spacing: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        name: browserIcon
                        size: Theme.iconSizeLarge
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: browserTitle
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                DankActionButton {
                    circular: false
                    iconName: "close"
                    iconSize: Theme.iconSize - 4
                    iconColor: Theme.surfaceText
                    hoverColor: Theme.errorHover
                    onClicked: fileBrowserModal.close()
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS

                StyledRect {
                    width: 32
                    height: 32
                    radius: Theme.cornerRadius
                    color: mouseArea.containsMouse
                           && currentPath !== homeDir ? Theme.surfaceVariant : "transparent"
                    opacity: currentPath !== homeDir ? 1.0 : 0.0

                    DankIcon {
                        anchors.centerIn: parent
                        name: "arrow_back"
                        size: Theme.iconSizeSmall
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: currentPath !== homeDir
                        cursorShape: currentPath
                                     !== homeDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: currentPath !== homeDir
                        onClicked: navigateUp()
                    }
                }

                StyledText {
                    text: fileBrowserModal.currentPath.replace("file://", "")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    width: parent.width - 40 - Theme.spacingS
                    elide: Text.ElideMiddle
                    anchors.verticalCenter: parent.verticalCenter
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
            }

            DankGridView {
                id: fileGrid

                width: parent.width
                height: parent.height - 80
                clip: true
                cellWidth: 150
                cellHeight: 130
                cacheBuffer: 260

                model: folderModel

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOff
                }

                delegate: StyledRect {
                    id: delegateRoot

                    required property bool fileIsDir
                    required property string filePath
                    required property string fileName
                    required property url fileURL

                    width: 140
                    height: 120
                    radius: Theme.cornerRadius
                    color: mouseArea.containsMouse ? Theme.surfaceVariant : "transparent"
                    border.color: Theme.outline
                    border.width: mouseArea.containsMouse ? 1 : 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        Item {
                            width: 80
                            height: 60
                            anchors.horizontalCenter: parent.horizontalCenter

                            CachingImage {
                                anchors.fill: parent
                                imagePath: !delegateRoot.fileIsDir ? delegateRoot.filePath : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: !delegateRoot.fileIsDir && isImageFile(
                                             delegateRoot.fileName)
                                maxCacheSize: 80
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "description"
                                size: Theme.iconSizeLarge
                                color: Theme.primary
                                visible: !delegateRoot.fileIsDir
                                         && !isImageFile(delegateRoot.fileName)
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "folder"
                                size: Theme.iconSizeLarge
                                color: Theme.primary
                                visible: delegateRoot.fileIsDir
                            }
                        }

                        StyledText {
                            text: delegateRoot.fileName || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            width: 120
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (delegateRoot.fileIsDir) {
                                navigateTo(delegateRoot.filePath)
                            } else {
                                fileSelected(delegateRoot.filePath)
                            }
                        }
                    }
                }
            }
        }
    }
}
