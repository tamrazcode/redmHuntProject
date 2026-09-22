const screen = document.getElementById('unconscious-screen');
const timer = document.getElementById('timer');
const hint = document.getElementById('hint');

function formatTime(totalSeconds) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') {
        screen.classList.add('visible');
        timer.classList.remove('hidden');
        return;
    }
    if (data.action === 'hide') {
        screen.classList.remove('visible');
        return;
    }
    if (data.action !== 'update') return;

    if (data.canWake) {
        // No separate "ready" plate: leave only the wake prompt.
        timer.textContent = '';
        timer.classList.add('hidden');
        hint.innerHTML = 'Нажмите <span class="key">Space</span>, чтобы подняться';
        hint.classList.add('ready');
    } else {
        timer.classList.remove('hidden');
        timer.textContent = formatTime(Math.max(0, Number(data.remaining) || 0));
        hint.textContent = 'Вы сможете подняться, когда таймер закончится';
        hint.classList.remove('ready');
    }
});
