// ===============================
// Keyboard Controls for IPTV Player
// ===============================

// Elementul video
let video = document.getElementById("video");

// Lista canalelor (populate de reader.js)
let channelList = [];
let currentChannelIndex = 0;

// ===============================
// Detectăm dacă utilizatorul tastează într-un input
// ===============================
function isTyping() {
    const active = document.activeElement;
    return (
        active &&
        (active.tagName === "INPUT" ||
         active.tagName === "TEXTAREA" ||
         active.isContentEditable)
    );
}

// ===============================
// Funcții Player
// ===============================

function togglePlayPause() {
    if (!video) return;
    video.paused ? video.play() : video.pause();
}

function volumeUp() {
    if (!video) return;
    video.volume = Math.min(1, video.volume + 0.05);
}

function volumeDown() {
    if (!video) return;
    video.volume = Math.max(0, video.volume - 0.05);
}

function toggleMute() {
    if (!video) return;
    video.muted = !video.muted;
}

// ===============================
// Fullscreen Toggle (F)
// ===============================
function toggleFullscreen() {
    if (!document.fullscreenElement) {
        // Intră în fullscreen
        if (video.requestFullscreen) video.requestFullscreen();
    } else {
        // Iese din fullscreen
        document.exitFullscreen();
    }
}

function nextChannel() {
    if (channelList.length === 0) return;
    currentChannelIndex = (currentChannelIndex + 1) % channelList.length;
    playChannel(currentChannelIndex);
}

function prevChannel() {
    if (channelList.length === 0) return;
    currentChannelIndex = (currentChannelIndex - 1 + channelList.length) % channelList.length;
    playChannel(currentChannelIndex);
}

function playChannel(index) {
    const url = channelList[index];
    if (!url) return;

    video.src = url;
    video.play();

    // Eveniment pentru highlight în groups.js
    const event = new Event("play");
    video.dispatchEvent(event);
}

// ===============================
// Evenimente Tastatură
// ===============================

document.addEventListener("keydown", function (e) {

    // Dacă tastezi într-un input, nu facem nimic
    if (isTyping()) return;

    // Forțăm focus pe video pentru a activa comenzile
    if (video) video.focus();

    switch (e.key) {

        case "p":          // P = Play/Pause
        case "P":
            e.preventDefault();
            togglePlayPause();
            break;

        case "ArrowUp":    // ↑ = Volum +
            volumeUp();
            break;

        case "ArrowDown":  // ↓ = Volum -
            volumeDown();
            break;

        case "ArrowRight": // → = Next channel
            nextChannel();
            break;

        case "ArrowLeft":  // ← = Previous channel
            prevChannel();
            break;

        case "m":          // M = Mute
        case "M":
            toggleMute();
            break;

        case "f":          // F = Fullscreen toggle
        case "F":
            toggleFullscreen();
            break;
    }
});