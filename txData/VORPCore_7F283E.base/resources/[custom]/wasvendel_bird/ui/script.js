const birdList = document.getElementById('bird-list');
const menuContainer = document.getElementById('menu-container');
const btnClose = document.getElementById('btn-close');
const birdSearch = document.getElementById('bird-search');

var birdsData = [];

function getNuiPath(path) {
    if (!path) return '';
    if (path.startsWith('http')) return path;
    return path.startsWith('img/') ? path : 'img/' + path;
}

function createBirdItem(b) {
    const div = document.createElement('div');
    div.className = 'bird-item';
    div.dataset.model = b.model;
    const iconPath = getNuiPath(b.icon);
    const name = b.name || b.model;
    div.innerHTML =
        '<img class="bird-icon" src="' + iconPath + '" alt="" onerror="this.src=\'img/bird_default.png\'">' +
        '<div class="bird-info">' +
        '<p class="bird-name">' + name + '</p>' +
        '<p class="bird-model">' + b.model + '</p>' +
        '</div>';
    div.addEventListener('click', function () {
        fetch('https://wasvendel_bird/select', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ model: b.model })
        });
    });
    return div;
}

function renderBirds(filter) {
    birdList.innerHTML = '';
    var q = (filter || '').toLowerCase().trim();
    var list = q ? birdsData.filter(function (b) {
        var name = (b.name || '').toLowerCase();
        var model = (b.model || '').toLowerCase();
        return name.indexOf(q) !== -1 || model.indexOf(q) !== -1;
    }) : birdsData;
    list.forEach(function (b) {
        birdList.appendChild(createBirdItem(b));
    });
}

function openMenu(birds) {
    birdsData = birds || [];
    birdSearch.value = '';
    renderBirds('');
    menuContainer.classList.add('active');
    birdSearch.focus();
}

birdSearch.addEventListener('input', function () {
    renderBirds(birdSearch.value);
});

function closeMenu() {
    menuContainer.classList.remove('active');
    fetch('https://wasvendel_bird/close', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

btnClose.addEventListener('click', closeMenu);

window.addEventListener('message', function (event) {
    const data = event.data;
    if (data.action === 'open') {
        openMenu(data.birds || []);
    } else if (data.action === 'close') {
        closeMenu();
    }
});
