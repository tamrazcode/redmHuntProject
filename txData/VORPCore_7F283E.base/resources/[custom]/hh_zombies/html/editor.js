const resource = typeof GetParentResourceName === "function"
    ? GetParentResourceName()
    : "hh_zombies";

function el(id) {
    return document.getElementById(id);
}

const hud = el("hud");
const picker = el("picker");
const hudTitle = el("hudTitle");
const hudLead = el("hudLead");
const hudStat = el("hudStat");
const hudRadius = el("hudRadius");
const recommendedEl = el("recommended");
const catalogEl = el("catalog");
const searchEl = el("search");
const zoneNameEl = el("zoneName");
const zoneCountEl = el("zoneCount");
const customHashEl = el("customHash");
const pickRadius = el("pickRadius");
const pickCount = el("pickCount");
const previewName = el("previewName");
const manager = el("manager");
const zoneListEl = el("zoneList");

let recommended = [];
let catalog = [];
let selected = new Set();
let activeName = "";
let searchTimer = null;
let pendingDelete = null;
let managerZones = [];

function post(name, data) {
    fetch(`https://${resource}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

function setStep(step) {
    document.querySelectorAll("#steps span").forEach((node) => {
        const value = Number(node.dataset.step);
        node.classList.toggle("active", value === step);
        node.classList.toggle("done", value < step);
    });
}

function showHud(data) {
    if (picker) {
        picker.classList.add("hidden");
    }
    if (manager) {
        manager.classList.add("hidden");
    }
    if (hud) {
        hud.classList.remove("hidden");
    }
    setStep(data.step || 1);
    if (hudTitle) {
        hudTitle.textContent = data.title || "";
    }
    if (hudLead) {
        hudLead.textContent = data.lead || "";
    }
    if (hudStat && hudRadius) {
        if (data.radius != null) {
            hudStat.classList.remove("hidden");
            hudRadius.textContent = Number(data.radius).toFixed(0);
        } else {
            hudStat.classList.add("hidden");
        }
    }
}

function hideAll() {
    if (hud) {
        hud.classList.add("hidden");
    }
    if (picker) {
        picker.classList.add("hidden");
    }
    if (manager) {
        manager.classList.add("hidden");
    }
    pendingDelete = null;
}

function rowHtml(entry, checked) {
    const tag = entry.tag
        ? `<span class="tag">${entry.tag}</span>`
        : "";
    return `
        <div class="row ${entry.name === activeName ? "active" : ""}" data-name="${entry.name}">
            <input type="checkbox" ${checked ? "checked" : ""}>
            <span class="name">${entry.name}</span>
            ${tag}
        </div>
    `;
}

function renderLists() {
    if (recommendedEl) {
        recommendedEl.innerHTML = recommended.map((entry) => rowHtml(entry, selected.has(entry.name))).join("");
    }
    if (catalogEl) {
        catalogEl.innerHTML = catalog.map((entry) => rowHtml(entry, selected.has(entry.name))).join("");
        catalogEl.classList.toggle("hidden", catalog.length === 0);
    }
    if (pickCount) {
        pickCount.textContent = String(selected.size);
    }
}

function toggleRow(row, fromCheckbox) {
    const name = row.dataset.name;
    if (!name) {
        return;
    }
    activeName = name;
    if (previewName) {
        previewName.textContent = name;
    }
    post("zoneEditorPreview", { name });
    const box = row.querySelector("input[type=checkbox]");
    if (!fromCheckbox && box) {
        box.checked = !box.checked;
    }
    if (box && box.checked) {
        selected.add(name);
    } else {
        selected.delete(name);
    }
    renderLists();
}

function bindList(root) {
    if (!root) {
        return;
    }
    root.addEventListener("click", (event) => {
        const row = event.target.closest(".row");
        if (!row) {
            return;
        }
        toggleRow(row, event.target.type === "checkbox");
    });
}

function addCustomHash() {
    if (!customHashEl) {
        return;
    }
    const name = (customHashEl.value || "").trim().toLowerCase();
    if (!name) {
        return;
    }
    if (!recommended.some((entry) => entry.name === name)) {
        recommended.unshift({ name, hash: "", tag: "свой" });
    }
    selected.add(name);
    activeName = name;
    if (previewName) {
        previewName.textContent = name;
    }
    customHashEl.value = "";
    post("zoneEditorPreview", { name });
    renderLists();
}

function openPicker(data) {
    if (hud) {
        hud.classList.add("hidden");
    }
    if (manager) {
        manager.classList.add("hidden");
    }
    if (picker) {
        picker.classList.remove("hidden");
    }
    recommended = data.recommended || [];
    catalog = data.catalog || [];
    selected = new Set(data.selected && data.selected.length
        ? data.selected
        : recommended.map((entry) => entry.name));
    if (zoneNameEl) {
        zoneNameEl.value = data.label || "";
        zoneNameEl.focus();
    }
    if (zoneCountEl) {
        const suggested = Math.max(8, Math.floor(Number(data.radius || 0) / 3));
        zoneCountEl.value = data.count || suggested;
    }
    if (pickRadius) {
        pickRadius.textContent = Number(data.radius || 0).toFixed(0);
    }
    activeName = recommended[0] ? recommended[0].name : "";
    if (previewName) {
        previewName.textContent = activeName || "";
    }
    if (searchEl) {
        searchEl.value = "";
    }
    renderLists();
}

function escapeHtml(text) {
    return String(text || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function renderZoneManager() {
    if (!zoneListEl) {
        return;
    }
    if (!managerZones.length) {
        zoneListEl.innerHTML = `<div class="empty-zones">Пока нет созданных зон.<br>F11 — нарисовать новую.</div>`;
        return;
    }
    zoneListEl.innerHTML = managerZones.map((zone) => {
        const confirming = pendingDelete === zone.id;
        return `
            <div class="zone-row" data-id="${escapeHtml(zone.id)}">
                <div class="zone-info">
                    <span class="name">${escapeHtml(zone.label || zone.id)}</span>
                    <span class="meta-line">${Number(zone.radius || 0).toFixed(0)} м · ${Number(zone.count || 0)} зомби</span>
                </div>
                <button type="button" class="danger${confirming ? " confirm" : ""}" data-id="${escapeHtml(zone.id)}">
                    ${confirming ? "Точно?" : "Удалить"}
                </button>
            </div>
        `;
    }).join("");
}

function openManager(data) {
    hideAll();
    pendingDelete = null;
    managerZones = data.zones || [];
    if (manager) {
        manager.classList.remove("hidden");
    }
    renderZoneManager();
}

window.addEventListener("message", (event) => {
    const data = event.data || {};
    if (data.action === "playZombieSound") {
        return;
    }
    if (data.action === "hud") {
        showHud(data);
    } else if (data.action === "picker") {
        openPicker(data);
    } else if (data.action === "manager") {
        openManager(data);
    } else if (data.action === "catalog") {
        catalog = data.catalog || [];
        renderLists();
    } else if (data.action === "hide") {
        hideAll();
    } else if (data.action === "hideManager") {
        if (manager) {
            manager.classList.add("hidden");
        }
        pendingDelete = null;
    } else if (data.action === "radius" && hudRadius && hudStat) {
        hudStat.classList.remove("hidden");
        hudRadius.textContent = Number(data.radius || 0).toFixed(0);
    }
});

bindList(recommendedEl);
bindList(catalogEl);

if (searchEl) {
    searchEl.addEventListener("input", () => {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(() => {
            post("zoneEditorSearch", { query: searchEl.value || "" });
        }, 180);
    });
}

const addHashBtn = el("addHashBtn");
if (addHashBtn) {
    addHashBtn.addEventListener("click", addCustomHash);
}
if (customHashEl) {
    customHashEl.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
            event.preventDefault();
            addCustomHash();
        }
    });
}

const cancelBtn = el("cancelBtn");
if (cancelBtn) {
    cancelBtn.addEventListener("click", () => post("zoneEditorCancel"));
}
const saveBtn = el("saveBtn");
if (saveBtn) {
    saveBtn.addEventListener("click", () => {
        post("zoneEditorSave", {
            label: zoneNameEl ? zoneNameEl.value : "",
            count: zoneCountEl ? Number(zoneCountEl.value) : 0,
            models: Array.from(selected),
        });
    });
}

document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") {
        return;
    }
    if (picker && !picker.classList.contains("hidden")) {
        post("zoneEditorCancel");
    } else if (manager && !manager.classList.contains("hidden")) {
        post("zoneManagerClose");
    }
});

if (zoneListEl) {
    zoneListEl.addEventListener("click", (event) => {
        const btn = event.target.closest("button.danger");
        if (!btn) {
            return;
        }
        const id = btn.dataset.id;
        if (!id) {
            return;
        }
        if (pendingDelete !== id) {
            pendingDelete = id;
            renderZoneManager();
            return;
        }
        pendingDelete = null;
        post("zoneManagerDelete", { id });
    });
}

const managerClose = el("managerClose");
if (managerClose) {
    managerClose.addEventListener("click", () => post("zoneManagerClose"));
}

post("zoneEditorReady", {});
