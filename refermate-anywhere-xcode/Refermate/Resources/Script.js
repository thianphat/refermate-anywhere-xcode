function show(platform, enabled, useSettingsInsteadOfPreferences) {
    document.body.classList.add(`platform-${platform}`);

    if (useSettingsInsteadOfPreferences) {
        document.getElementsByClassName('platform-mac state-on body')[0].innerText = "You're cash back and commission ready. Visit your favorite store to start earning.";
        document.getElementsByClassName('platform-mac state-off body')[0].innerText = "You're only one click away from cash back and commission at over 30,000 stores.";
        document.getElementsByClassName('platform-mac state-unknown body')[0].innerText = "You can turn on Refermate Anywhere’s extension in the Extensions section of Safari Settings.";
        document.getElementsByClassName('platform-mac open-preferences')[0].innerText = "Open Safari Settings";
        document.getElementsByClassName('platform-mac close-app-window')[0].innerText = "Done";
    }

    if (typeof enabled === "boolean") {
        document.body.classList.toggle(`state-on`, enabled);
        document.body.classList.toggle(`state-off`, !enabled);
    } else {
        document.body.classList.remove(`state-on`);
        document.body.classList.remove(`state-off`);
    }
}

function openPreferences() {
    webkit.messageHandlers.controller.postMessage("open-preferences");
}

function closeWindow() {
    webkit.messageHandlers.controller.postMessage("close-app-window");
}

document.querySelector("button.open-preferences").addEventListener("click", openPreferences);
document.querySelector("button.close-app-window").addEventListener("click", closeWindow);
