/* GLIA installer slideshow - minimal single slide */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#1a1c2c"
            Column {
                anchors.centerIn: parent
                spacing: 24
                Text {
                    text: "GLIA — GNU/Linux + AI"
                    color: "#4fd1c5"
                    font.pixelSize: 40
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Your terminal, with an AI guide built in.\nThe AI model is being copied with the system:\nno downloads needed on first boot."
                    color: "#ffffff"
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "After the reboot, log in and answer one question:\nwhat do you want to call your assistant?"
                    color: "#a0aec0"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
