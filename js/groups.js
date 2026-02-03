// =======================================
// 1. Interceptăm fetch pentru playlist remote
// =======================================
(function() {
    const originalFetch = window.fetch;
    window.fetch = async function(...args) {
        const response = await originalFetch.apply(this, args);

        try {
            const clone = response.clone();
            const text = await clone.text();

            if (text.includes("#EXTM3U")) {
                window.rawPlaylist = text;
            }
        } catch (e) {}

        return response;
    };
})();

// =======================================
// 2. Interceptăm FileReader pentru playlist local
// =======================================
(function() {
    const originalReadAsText = FileReader.prototype.readAsText;

    FileReader.prototype.readAsText = function(blob) {
        this.addEventListener("load", function() {
            if (this.result.includes("#EXTM3U")) {
                window.rawPlaylist = this.result;
            }
        });
        originalReadAsText.call(this, blob);
    };
})();

// =======================================
// 3. După ce lista este generată, construim grupurile
// =======================================
document.addEventListener("DOMContentLoaded", () => {
    const videoList = document.getElementById("video-list");

    const observer = new MutationObserver(() => {
        if (videoList.children.length > 0 && window.rawPlaylist) {
            observer.disconnect();
            buildGroups();
        }
    });

    observer.observe(videoList, { childList: true });
});

// =======================================
// 4. Extragem group-title pentru fiecare canal
// =======================================
function getGroupForChannel(channelName) {
    if (!window.rawPlaylist) return "Other";

    const lines = window.rawPlaylist.split("\n");

    for (let line of lines) {
        if (line.includes(channelName)) {
            const match = line.match(/group-title="([^"]+)"/i);
            if (match) return match[1];
        }
    }

    return "Other";
}

// =======================================
// 5. Construim grupurile + accordion + highlight
// =======================================
function buildGroups() {
    const videoList = document.getElementById("video-list");
    const items = [...videoList.querySelectorAll("li")];
    const groups = {};

    items.forEach(li => {
        const name = li.textContent.trim();
        const group = getGroupForChannel(name);

        if (!groups[group]) groups[group] = [];
        groups[group].push(li);
    });

    videoList.innerHTML = "";

    Object.keys(groups).forEach((groupName, index) => {
        const wrapper = document.createElement("div");
        wrapper.className = "group-wrapper";

        const header = document.createElement("div");
        header.className = "group-header";
        header.textContent = groupName;

        const content = document.createElement("div");
        content.className = "group-content";

        groups[groupName].forEach(li => content.appendChild(li));

// This line opens the first group-title by default.
// Uncomment if you want the first group to auto-expand.
//        if (index === 0) content.classList.add("open");

        header.addEventListener("click", () => {
            document.querySelectorAll(".group-content").forEach(c => {
                if (c !== content) c.classList.remove("open");
            });
            content.classList.toggle("open");
        });

        wrapper.appendChild(header);
        wrapper.appendChild(content);
        videoList.appendChild(wrapper);
    });
}