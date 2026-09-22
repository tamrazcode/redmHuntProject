const RESOURCE = "wasvendel_pedmenu";

const menuContainer = document.getElementById("menu-container");
const pedList = document.getElementById("ped-list");
const pedSearch = document.getElementById("ped-search");
const categorySelect = document.getElementById("category-select");
const categoryTrigger = document.getElementById("category-trigger");
const categoryLabel = document.getElementById("category-label");
const categoryDropdown = document.getElementById("category-dropdown");
const btnClose = document.getElementById("btn-close");
const menuFooter = document.getElementById("menu-footer");
const footerModel = document.getElementById("footer-model");
const footerCopy = document.getElementById("footer-copy");
const outfitVal = document.getElementById("outfit-val");
const outfitMinus = document.getElementById("outfit-minus");
const outfitPlus = document.getElementById("outfit-plus");
const btnPreview = document.getElementById("btn-preview");
const btnApply = document.getElementById("btn-apply");
const btnRestore = document.getElementById("btn-restore");
const menuTitle = document.getElementById("menu-title");
const outfitLabel = document.getElementById("outfit-label");
const copyToast = document.getElementById("copy-toast");

let pedsData = [];
let categoriesData = [];
let lang = {};
let selectedPed = null;
let maxOutfits = 1;
let currentOutfit = 0;
let currentCategory = "all";
let previewActive = false;
let categoryOpen = false;
let copyToastTimer = null;

const DEFAULT_SHOW = 150;
const MAX_FILTERED = 250;

const COPY_ICON_HTML =
    '<svg class="copy-icon" viewBox="0 0 24 24" aria-hidden="true">' +
    '<rect x="9" y="9" width="11" height="11" rx="1.5"></rect>' +
    '<path d="M7 15H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v1"></path>' +
    "</svg>";

function nuiPost(endpoint, payload) {
    return fetch("https://" + RESOURCE + "/" + endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload || {}),
    });
}

function applyLang() {
    menuTitle.textContent = lang.menuTitle || "Ped Menu";
    pedSearch.placeholder = lang.searchPlaceholder || "Search...";
    outfitLabel.textContent = lang.outfit || "Outfit";
    btnPreview.textContent = lang.preview || "Preview";
    btnApply.textContent = lang.apply || "Apply";
    btnRestore.textContent = lang.restore || "Restore";
    copyToast.textContent = lang.copied || "Copied";
    footerCopy.title = lang.copyTitle || "Copy";
}

function getCategoryLabel(id) {
    const cat = categoriesData.find(function (c) {
        return c.id === id;
    });
    return cat ? cat.label : lang.allCategories || "All";
}

function closeCategoryDropdown() {
    categoryOpen = false;
    categoryDropdown.classList.add("hidden");
    categorySelect.classList.remove("open");
}

function openCategoryDropdown() {
    categoryOpen = true;
    categoryDropdown.classList.remove("hidden");
    categorySelect.classList.add("open");
}

function toggleCategoryDropdown() {
    if (categoryOpen) {
        closeCategoryDropdown();
    } else {
        openCategoryDropdown();
    }
}

function setCategory(id) {
    currentCategory = id || "all";
    closeCategoryDropdown();
    buildCategoryDropdown();
    previewActive = false;
    clearSelection();
    renderPedList();
}

function buildCategoryDropdown() {
    categoryDropdown.innerHTML = "";
    const list = categoriesData.length
        ? categoriesData
        : [{ id: "all", label: lang.allCategories || "All" }];

    list.forEach(function (cat) {
        const btn = document.createElement("button");
        btn.type = "button";
        btn.className = "custom-select-option";
        if (cat.id === currentCategory) {
            btn.classList.add("active");
        }
        btn.textContent = cat.label;
        btn.addEventListener("click", function () {
            setCategory(cat.id);
        });
        categoryDropdown.appendChild(btn);
    });

    categoryLabel.textContent = getCategoryLabel(currentCategory);
}

function showCopyToast() {
    copyToast.classList.remove("hidden");
    if (copyToastTimer) {
        clearTimeout(copyToastTimer);
    }
    copyToastTimer = setTimeout(function () {
        copyToast.classList.add("hidden");
    }, 1400);
}

function copyText(text) {
    if (!text) return;

    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    area.style.left = "-9999px";
    area.style.top = "0";
    document.body.appendChild(area);
    area.focus();
    area.select();
    area.setSelectionRange(0, text.length);

    let copied = false;
    try {
        copied = document.execCommand("copy");
    } catch (e) {
        copied = false;
    }

    document.body.removeChild(area);

    if (copied) {
        showCopyToast();
    }
}

function clampOutfit(value) {
    const max = Math.max(1, maxOutfits) - 1;
    let v = parseInt(value, 10);
    if (isNaN(v)) v = 0;
    if (v < 0) v = 0;
    if (v > max) v = max;
    return v;
}

function updateOutfitControls() {
    currentOutfit = clampOutfit(currentOutfit);
    outfitVal.textContent = String(currentOutfit);
    const max = Math.max(1, maxOutfits) - 1;
    outfitMinus.disabled = currentOutfit <= 0;
    outfitPlus.disabled = currentOutfit >= max;
}

function updatePreviewOutfit() {
    if (!previewActive || !selectedPed) return;
    nuiPost("setOutfit", {
        model: selectedPed.model,
        outfit: currentOutfit,
    });
}

function selectPed(ped) {
    selectedPed = ped;
    maxOutfits = ped.outfits || 1;
    currentOutfit = 0;
    previewActive = false;
    menuFooter.classList.remove("hidden");
    footerModel.textContent = ped.model;
    updateOutfitControls();
    nuiPost("clearPreview");
}

function clearSelection() {
    selectedPed = null;
    previewActive = false;
    menuFooter.classList.add("hidden");
    nuiPost("clearPreview");
}

function getFilteredList(query, category) {
    const q = (query || "").toLowerCase().trim();
    const cat = category || "all";
    let list = pedsData;

    if (cat !== "all") {
        list = list.filter(function (ped) {
            return ped.category === cat;
        });
    }

    if (q) {
        list = list.filter(function (ped) {
            return (ped.model || "").toLowerCase().indexOf(q) !== -1;
        });
        return list.slice(0, MAX_FILTERED);
    }

    if (cat !== "all") {
        return list;
    }

    return list.slice(0, DEFAULT_SHOW);
}

function createPedItem(ped) {
    const div = document.createElement("div");
    div.className = "ped-item";
    if (selectedPed && selectedPed.model === ped.model) {
        div.classList.add("selected");
    }

    const name = document.createElement("p");
    name.className = "ped-name copyable";
    name.textContent = ped.model;

    const copyBtn = document.createElement("button");
    copyBtn.type = "button";
    copyBtn.className = "btn-copy btn-copy-inline";
    copyBtn.title = lang.copyTitle || "Copy";
    copyBtn.setAttribute("aria-label", lang.copyTitle || "Copy");
    copyBtn.innerHTML = COPY_ICON_HTML;
    copyBtn.addEventListener("click", function (event) {
        event.stopPropagation();
        copyText(ped.model);
    });

    const outfits = document.createElement("span");
    outfits.className = "ped-outfits";
    outfits.textContent = String(ped.outfits || 1);

    const main = document.createElement("div");
    main.className = "ped-main";
    main.appendChild(name);
    main.appendChild(copyBtn);

    div.appendChild(main);
    div.appendChild(outfits);

    div.addEventListener("click", function () {
        document.querySelectorAll(".ped-item.selected").forEach(function (el) {
            el.classList.remove("selected");
        });
        div.classList.add("selected");
        selectPed(ped);
    });

    return div;
}

function renderPedList() {
    pedList.innerHTML = "";
    const list = getFilteredList(pedSearch.value, currentCategory);

    list.forEach(function (ped) {
        pedList.appendChild(createPedItem(ped));
    });
}

function openMenu(data) {
    pedsData = data.peds || [];
    categoriesData = data.categories || [];
    lang = data.lang || {};
    currentCategory = "all";
    previewActive = false;
    applyLang();
    buildCategoryDropdown();
    closeCategoryDropdown();
    pedSearch.value = "";
    clearSelection();
    renderPedList();
    menuContainer.classList.add("active");
    pedSearch.focus();
}

function closeMenu() {
    closeCategoryDropdown();
    previewActive = false;
    nuiPost("clearPreview");
    menuContainer.classList.remove("active");
    nuiPost("close");
}

categoryTrigger.addEventListener("click", function (event) {
    event.stopPropagation();
    toggleCategoryDropdown();
});

document.addEventListener("click", function (event) {
    if (!categorySelect.contains(event.target)) {
        closeCategoryDropdown();
    }
});

pedSearch.addEventListener("input", renderPedList);

btnClose.addEventListener("click", closeMenu);

footerCopy.addEventListener("click", function () {
    if (selectedPed) {
        copyText(selectedPed.model);
    }
});

outfitMinus.addEventListener("click", function () {
    currentOutfit = clampOutfit(currentOutfit - 1);
    updateOutfitControls();
    updatePreviewOutfit();
});

outfitPlus.addEventListener("click", function () {
    currentOutfit = clampOutfit(currentOutfit + 1);
    updateOutfitControls();
    updatePreviewOutfit();
});

btnPreview.addEventListener("click", function () {
    if (!selectedPed) return;
    previewActive = true;
    nuiPost("preview", {
        model: selectedPed.model,
        outfit: currentOutfit,
    });
});

btnApply.addEventListener("click", function () {
    if (!selectedPed) return;
    nuiPost("apply", {
        model: selectedPed.model,
        outfit: currentOutfit,
    });
});

btnRestore.addEventListener("click", function () {
    previewActive = false;
    nuiPost("restore");
});

window.addEventListener("message", function (event) {
    const data = event.data;
    if (data.action === "open") {
        openMenu(data);
    } else if (data.action === "close") {
        menuContainer.classList.remove("active");
    }
});

document.addEventListener("keydown", function (event) {
    if (!menuContainer.classList.contains("active")) return;

    if (event.key === "Escape") {
        if (categoryOpen) {
            closeCategoryDropdown();
            return;
        }
        closeMenu();
    }
});
