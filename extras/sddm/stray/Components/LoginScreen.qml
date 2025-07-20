import QtQuick 6.8
import QtMultimedia 6.8

Item {

    //Color for the elements inside (white affected by the lighting)
    property var primaryColor: "#7c8b80" 

    id: loginScreen

    /* 
       The real size of the screen region in world.
       Scaled by 10 as the qt will render the child components on a lower resolution texture,
       when any layer effect applied. 
       Increasing the rendering texture size is not helping with the text elements.
    */
    width: 846
    height: 471
    x: 0
    y: 0

    function computeHomography() {
        let fov_deg = 61.421;
        let w = Screen.width;
        let h = Screen.height;

        let fov = fov_deg * Math.PI / 180;
        let fk = w / (2 * Math.tan(fov / 2));

        let cx = w / 2;
        let cy = h / 2;

        let K = Qt.matrix4x4(
            fk, 0,  0, cx,
            0,  fk, 0, cy,
            0,  0,  1, 0,
            0,  0,  0, 1,
        );

        /* Normalized homography */
        let Hn = Qt.matrix4x4(
             4.05012762e-04, -8.13453893e-05,  0,   1.69079959e-01,
            -4.21802195e-05,  4.13855464e-04,  0,   8.94329846e-02,
             0,               0,               1,   0,
            -2.38332520e-04, -2.11478906e-04,  0,   1,
        );

        return K.times(Hn);
    }

    transform: Matrix4x4 {
        matrix: computeHomography();
    }

    property alias timePosition: loginPanel.timePosition
    LoginPanel{
        id: loginPanel
        anchors.fill: parent
        opacity: (JSON.parse(config.StartScreenEffect) && screen_start.position < 500) ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 100; easing.type: Easing.InOutQuad }
        }
    }

    MediaPlayer {
        id: screen_start
        source: "../sounds/screen_start.wav"
        audioOutput: AudioOutput { 
            volume: config.Volume
            muted: !JSON.parse(config.Audio)
        }
        autoPlay: true
    }

}

