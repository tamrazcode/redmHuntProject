let activeSounds = 0;
let maxSimultaneous = 7;
const players = new Set();
const resource = typeof GetParentResourceName === "function"
    ? GetParentResourceName()
    : "hh_zombies";

window.addEventListener("message", (event) => {
    const data = event.data;
    if (!data || data.action !== "playZombieSound" || !data.file) {
        return;
    }

    maxSimultaneous = Number(data.maxSimultaneous) || 7;
    if (activeSounds >= maxSimultaneous && !data.priority) {
        return;
    }

    const url = `https://cfx-nui-${resource}/${data.file}`;
    const volume = Math.max(0, Math.min(1, Number(data.volume) || 0));
    activeSounds += 1;

    let player;
    const release = () => {
        activeSounds = Math.max(0, activeSounds - 1);
        if (player) {
            players.delete(player);
            if (typeof player.unload === "function") {
                player.unload();
            }
        }
    };

    if (typeof Howl === "function") {
        player = new Howl({
            src: [url],
            volume,
            preload: true,
            onend: release,
            onloaderror: release,
            onplayerror: release,
        });
        players.add(player);
        player.play();
        return;
    }

    player = new Audio(url);
    player.volume = volume;
    players.add(player);
    player.addEventListener("ended", release, { once: true });
    player.addEventListener("error", release, { once: true });
    player.play().catch(release);
});
