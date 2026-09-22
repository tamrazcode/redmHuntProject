// =================================================================
// HUNT: Hard RP — Animations NUI Controller
// Obsidian UI, Left Sidebar, Orange Favorites, MMB Camera & Ghost Ped Preview
// Category & Scroll Persistence, WebAudio Chimes from thehunt_menu
// =================================================================

const AnimUI = (function () {
  let allAnimations = [];
  let categories = [];
  let activeCategory = 'All';
  let searchQuery = '';
  let bodyMode = 'full';
  let playingLabel = null;
  let previewLabel = null;
  let dragBound = false;
  let isWindowFocused = true;
  let isMMBActive = false;
  let pinnedList = [];

  // Состояние сохранения категории и прокрутки при закрытии
  let savedCategory = null;
  let categoryScrollPositions = {};

  // DOM Elements
  const appEl = document.getElementById('animApp');
  const windowEl = document.getElementById('animWindow');
  const headerEl = document.getElementById('animHeader');
  const searchInput = document.getElementById('searchInput');
  const btnClearSearch = document.getElementById('btnClearSearch');
  const tabFavorites = document.getElementById('tabFavorites');
  const favCountEl = document.getElementById('favCount');
  const sidebarCategories = document.getElementById('sidebarCategories');
  const animGrid = document.getElementById('animGrid');
  const emptyState = document.getElementById('emptyState');
  const btnClose = document.getElementById('btnClose');
  const btnStopAnim = document.getElementById('btnStopAnim');
  const btnModeFull = document.getElementById('btnModeFull');
  const btnModeUpper = document.getElementById('btnModeUpper');
  const radialContainer = document.getElementById('radialContainer');
  const radialSlots = [1, 2, 3, 4].map(i => document.getElementById(`radialSlot${i}`));

  // SVG Иконки категорий (Строгий векторный стиль без эмодзи)
  const CATEGORY_ICONS = {
    Favorites: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>',
    All: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>',
    Poses: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="7" r="4"/><path d="M5.5 21v-3.5a4.5 4.5 0 0 1 9 0V21"/><path d="M18.5 21v-7a3 3 0 0 0-3-3"/></svg>',
    Walks: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="13" cy="4" r="2"/><path d="M14 8l-3 4-3-1-3 4"/><path d="M11 12l2 4 4 3"/></svg>',
    Gestures: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 11V6a2 2 0 0 0-4 0v5M14 10V4a2 2 0 0 0-4 0v7M10 10.5V6a2 2 0 0 0-4 0v8a7 7 0 0 0 14 0v-4a2 2 0 0 0-4 0"/></svg>',
    Emotes: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2M9 9h.01M15 9h.01"/></svg>',
    Dances: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18V5l12-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm12-2a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"/></svg>',
    Scenarios: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>'
  };

  // Русские названия категорий
  const CATEGORY_LABELS_RU = {
    All: 'Все',
    Poses: 'Позы',
    Gestures: 'Жесты',
    Emotes: 'Эмоции',
    Dances: 'Танцы',
    Scenarios: 'Сценарии',
    Walks: 'Походки',
    Favorites: 'Избранное'
  };

  // =================================================================
  // WEBAUDIO SOUND CHIMES (Аналогично thehunt_menu)
  // =================================================================

  let audioCtx = null;

  function playUiSound(freq = 600, type = 'sine', duration = 0.08, gainVal = 0.035) {
    // UI sounds disabled for the animation menu.
    return;
  }

  function playSuccessChime() {
    playUiSound(540, 'sine', 0.07, 0.04);
    setTimeout(() => {
      playUiSound(720, 'sine', 0.12, 0.035);
    }, 60);
  }

  // Переключение фокуса окна
  function setWindowFocusState(focused) {
    if (isWindowFocused === focused) return;
    isWindowFocused = focused;

    if (windowEl) {
      windowEl.classList.toggle('is-unfocused', !focused);
    }

    fetch(`https://${GetParentResourceName()}/thehunt_animations:setWindowFocus`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ isFocused: focused })
    }).catch(() => { });
  }

  // Перетаскивание окна
  function setupDragging() {
    if (dragBound || !headerEl || !windowEl) return;

    let drag = null;
    const finishDrag = (e) => {
      if (!drag || (e && e.pointerId !== drag.pointerId)) return;
      if (headerEl.hasPointerCapture(drag.pointerId)) {
        headerEl.releasePointerCapture(drag.pointerId);
      }
      drag = null;
      windowEl.classList.remove('is-dragging');
      headerEl.classList.remove('is-dragging');
    };

    headerEl.addEventListener('pointerdown', (e) => {
      if (e.button !== 0 || appEl.classList.contains('hidden')) return;
      setWindowFocusState(true);
      if (e.target.closest('button, input')) return;

      const rect = windowEl.getBoundingClientRect();
      windowEl.style.position = 'fixed';
      windowEl.style.left = `${rect.left}px`;
      windowEl.style.top = `${rect.top}px`;
      windowEl.style.bottom = 'auto';
      windowEl.style.right = 'auto';

      drag = {
        pointerId: e.pointerId,
        offsetX: e.clientX - rect.left,
        offsetY: e.clientY - rect.top
      };

      headerEl.setPointerCapture(e.pointerId);
      windowEl.classList.add('is-dragging');
      headerEl.classList.add('is-dragging');
      e.preventDefault();
    });

    headerEl.addEventListener('pointermove', (e) => {
      if (!drag || e.pointerId !== drag.pointerId) return;

      const rect = windowEl.getBoundingClientRect();
      const maxLeft = Math.max(0, window.innerWidth - rect.width);
      const maxTop = Math.max(0, window.innerHeight - rect.height);
      windowEl.style.left = `${Math.max(0, Math.min(maxLeft, e.clientX - drag.offsetX))}px`;
      windowEl.style.top = `${Math.max(0, Math.min(maxTop, e.clientY - drag.offsetY))}px`;
      e.preventDefault();
    });

    headerEl.addEventListener('pointerup', finishDrag);
    headerEl.addEventListener('pointercancel', finishDrag);
    dragBound = true;
  }

  // Фильтрация анимаций
  function getFilteredAnimations() {
    let list = allAnimations;

    // Фильтр по категории
    if (activeCategory === 'Favorites') {
      list = list.filter(a => a.Favorite);
      // Закрепленные анимации (Pinned) идут ВЫШЕ ВСЕХ по очереди закрепления (слоты 1..4)
      list.sort((a, b) => {
        const idxA = pinnedList.indexOf(a.Label);
        const idxB = pinnedList.indexOf(b.Label);
        const pinA = idxA !== -1 ? idxA : 999;
        const pinB = idxB !== -1 ? idxB : 999;
        if (pinA !== pinB) return pinA - pinB;
        return a.Label.localeCompare(b.Label, 'ru');
      });
    } else if (activeCategory !== 'All') {
      list = list.filter(a => a.Category === activeCategory);
    }

    // Фильтр по поисковому запросу
    const q = searchQuery.trim().toLowerCase();
    if (q) {
      list = list.filter(a => a.Label && a.Label.toLowerCase().includes(q));
    }

    return list;
  }

  // Отрисовка сайдбара категорий
  function renderCategories() {
    const favCount = allAnimations.filter(a => a.Favorite).length;

    // Обновляем кнопку Избранное (вверху сайдбара)
    if (favCountEl) favCountEl.textContent = favCount;
    if (tabFavorites) {
      tabFavorites.classList.toggle('active', activeCategory === 'Favorites');
    }

    // Отрисовка остальных категорий
    if (!sidebarCategories) return;

    let html = '';
    categories.forEach(cat => {
      if (cat.id === 'Favorites') return; // Избранное уже вверху

      const isAct = cat.id === activeCategory;
      const iconSvg = CATEGORY_ICONS[cat.id] || CATEGORY_ICONS.All;

      let count = 0;
      if (cat.id === 'All') {
        count = allAnimations.length;
      } else {
        count = allAnimations.filter(a => a.Category === cat.id).length;
      }

      html += `
        <button class="nav-tab ${isAct ? 'active' : ''}" data-cat="${cat.id}">
          <div class="nav-tab-left">
            <div class="tab-icon">${iconSvg}</div>
            <span class="tab-label">${cat.label}</span>
          </div>
          <span class="tab-count">${count}</span>
        </button>
      `;
    });

    sidebarCategories.innerHTML = html;

    sidebarCategories.querySelectorAll('.nav-tab').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const catId = e.currentTarget.dataset.cat;
        if (catId && catId !== activeCategory) {
          playUiSound(650, 'sine', 0.06, 0.035);
          if (animGrid) {
            categoryScrollPositions[activeCategory] = animGrid.scrollTop;
          }
          activeCategory = catId;
          renderCategories();
          renderAnimations();

          // Восстанавливаем позицию прокрутки для выбранной категории
          setTimeout(() => {
            if (animGrid) {
              animGrid.scrollTop = categoryScrollPositions[activeCategory] || 0;
            }
          }, 0);
        }
      });
    });
  }

  // Отрисовка сетки карточек анимаций
  function renderAnimations() {
    if (!animGrid) return;
    const items = getFilteredAnimations();

    if (items.length === 0) {
      animGrid.innerHTML = '';
      if (emptyState) emptyState.classList.remove('hidden');
      return;
    }

    if (emptyState) emptyState.classList.add('hidden');

    let html = '';
    items.forEach((item, idx) => {
      const isPlaying = (playingLabel && playingLabel === item.Label);
      const isPreviewing = (previewLabel && previewLabel === item.Label);
      const isFav = Boolean(item.Favorite);
      const isPinned = pinnedList.includes(item.Label);
      const pinSlot = isPinned ? (pinnedList.indexOf(item.Label) + 1) : 0;
      const isWalk = (item.Category === 'Walks' || item.Type === 'Walkstyle');

      html += `
        <div class="anim-card ${isPlaying ? 'is-playing' : ''} ${isPreviewing ? 'is-previewing' : ''} ${isPinned ? 'is-pinned' : ''} ${isWalk ? 'is-walkable' : ''}" data-label="${escapeHtml(item.Label)}" data-idx="${idx}">
          <div class="card-left">
            <div class="playing-dot"></div>
            <div class="preview-dot"></div>
            ${isPinned ? `<span class="pin-slot-badge" title="Слот ${pinSlot} в радиальном меню">${pinSlot}</span>` : ''}
            <span class="anim-card-title">${escapeHtml(item.Label)}</span>
          </div>
          <div class="card-actions">
            ${activeCategory === 'Favorites' ? `
              <button class="btn-pin ${isPinned ? 'is-pinned' : ''}" data-label="${escapeHtml(item.Label)}" title="${isPinned ? 'Открепить от быстрого меню B' : 'Закрепить в быстром меню B (макс. 4)'}">
                <svg viewBox="0 0 24 24"><path d="M16 3H8l2 7-3 3v2h6v6l1 1 1-1v-6h6v-2l-3-3 2-7z"/></svg>
              </button>
            ` : ''}
            <button class="btn-fav-star ${isFav ? 'is-fav' : ''}" data-label="${escapeHtml(item.Label)}" title="${isFav ? 'Убрать из избранного' : 'Добавить в избранное'}">
              <svg viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>
            </button>
          </div>
        </div>
      `;
    });

    animGrid.innerHTML = html;

    // ЛКМ по карточке: Запуск анимации на персонаже
    animGrid.querySelectorAll('.anim-card').forEach(card => {
      card.addEventListener('click', (e) => {
        if (e.target.closest('.btn-fav-star') || e.target.closest('.btn-pin')) return;
        const label = e.currentTarget.dataset.label;
        if (label) playAnimation(label);
      });

      // ПКМ по карточке: Режим предпросмотра на призрачном клоне
      card.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        const label = e.currentTarget.dataset.label;
        if (label) togglePreview(label);
      });
    });

    // Клик по кнопке закрепления (Pin)
    animGrid.querySelectorAll('.btn-pin').forEach(pin => {
      pin.addEventListener('click', (e) => {
        e.stopPropagation();
        const label = e.currentTarget.dataset.label;
        if (label) togglePin(label);
      });
    });

    // Клик по звездочке: Добавление / удаление из избранного
    animGrid.querySelectorAll('.btn-fav-star').forEach(star => {
      star.addEventListener('click', (e) => {
        e.stopPropagation();
        const label = e.currentTarget.dataset.label;
        if (label) toggleFavorite(label);
      });
    });
  }

  // Запуск анимации на самом персонаже (ЛКМ)
  function playAnimation(label) {
    if (document.activeElement && typeof document.activeElement.blur === 'function') {
      document.activeElement.blur();
    }
    playingLabel = label;
    previewLabel = null;
    updateCardStates();
    playSuccessChime();

    fetch(`https://${GetParentResourceName()}/thehunt_animations:play`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        label: label,
        bodyMode: bodyMode
      })
    }).catch(() => { });
  }

  // Переключение предпросмотра (ПКМ)
  function togglePreview(label) {
    playUiSound(580, 'sine', 0.06, 0.03);

    if (previewLabel === label) {
      previewLabel = null;
    } else {
      previewLabel = label;
    }
    updateCardStates();

    fetch(`https://${GetParentResourceName()}/thehunt_animations:preview`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        label: label,
        bodyMode: bodyMode
      })
    }).catch(() => { });
  }

  // Остановка анимации (Z / кнопка)
  function stopAnimation() {
    if (document.activeElement && typeof document.activeElement.blur === 'function') {
      document.activeElement.blur();
    }
    playingLabel = null;
    previewLabel = null;
    updateCardStates();
    playUiSound(440, 'sine', 0.06, 0.03);

    fetch(`https://${GetParentResourceName()}/thehunt_animations:setInputFocus`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hasFocus: false })
    }).catch(() => { });

    fetch(`https://${GetParentResourceName()}/thehunt_animations:stop`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(() => { });
  }

  // Переключение избранного (Клик по звездочке)
  function toggleFavorite(label) {
    const item = allAnimations.find(a => a.Label === label);
    if (!item) return;

    item.Favorite = !item.Favorite;
    if (!item.Favorite) {
      // Если анимацию убрали из избранного — автоматически снимаем закрепление
      pinnedList = pinnedList.filter(l => l !== label);
    }
    playSuccessChime();
    renderCategories();
    renderAnimations();

    fetch(`https://${GetParentResourceName()}/thehunt_animations:toggleFavorite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        label: label,
        isFavorite: item.Favorite
      })
    }).catch(() => { });
  }

  // Переключение закрепления для быстрого радиального меню B (максимум 4 штуки)
  function togglePin(label) {
    const isPinned = pinnedList.includes(label);
    if (!isPinned) {
      if (pinnedList.length >= 4) {
        playUiSound(280, 'sawtooth', 0.08, 0.05);
        fetch(`https://${GetParentResourceName()}/thehunt_animations:notifyMaxPins`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        }).catch(() => { });
        return;
      }
      pinnedList.push(label);
      playSuccessChime();
    } else {
      pinnedList = pinnedList.filter(l => l !== label);
      playUiSound(480, 'sine', 0.05, 0.03);
    }

    renderAnimations();

    fetch(`https://${GetParentResourceName()}/thehunt_animations:togglePin`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        label: label,
        isPinned: !isPinned
      })
    }).catch(() => { });
  }

  // =================================================================
  // ЛОГИКА РАДИАЛЬНОГО МЕНЮ БЫСТРОГО ДОСТУПА (УДЕРЖАНИЕ B)
  // =================================================================

  let currentRadialSlots = [];

  function openRadialMenu(slots) {
    if (!radialContainer) return;
    currentRadialSlots = slots || [];

    for (let i = 1; i <= 4; i++) {
      const slotEl = document.getElementById(`radialSlot${i}`);
      const iconEl = document.getElementById(`slotIcon${i}`);
      const labelEl = document.getElementById(`slotLabel${i}`);
      const subEl = document.getElementById(`slotSub${i}`);
      if (!slotEl) continue;

      const slotData = currentRadialSlots[i - 1];
      if (slotData && !slotData.isEmpty) {
        slotEl.classList.remove('is-empty');
        slotEl.classList.add('has-anim');
        if (labelEl) labelEl.textContent = slotData.label;
        if (subEl) {
          const cat = categories.find(c => c.id === slotData.category);
          subEl.textContent = (cat && cat.label) ? cat.label : (CATEGORY_LABELS_RU[slotData.category] || slotData.category || 'Закреплено');
        }
        if (iconEl) {
          iconEl.textContent = i;
        }

        // Клик по слоту: воспроизведение анимации
        slotEl.onclick = (e) => {
          e.stopPropagation();
          playRadialAnimation(slotData.label, 'full');
        };
        // ПКМ по слоту запускает ту же анимацию в режиме «Только верх»,
        // а не открывает обычное контекстное меню браузера.
        slotEl.oncontextmenu = (e) => {
          e.preventDefault();
          e.stopPropagation();
          playRadialAnimation(slotData.label, 'upper');
        };
        slotEl.onmouseenter = () => {
          playUiSound(720, 'sine', 0.04, 0.025);
        };
      } else {
        slotEl.classList.add('is-empty');
        slotEl.classList.remove('has-anim');
        if (labelEl) labelEl.textContent = `Слот ${i}`;
        if (subEl) subEl.textContent = 'Пусто';
        if (iconEl) {
          iconEl.textContent = i;
        }
        slotEl.onclick = null;
        slotEl.oncontextmenu = null;
        slotEl.onmouseenter = null;
      }
    }

    radialContainer.classList.remove('hidden');
  }

  function closeRadialMenu() {
    if (!radialContainer) return;
    radialContainer.classList.add('hidden');
  }

  function playRadialAnimation(label, bodyMode = 'full') {
    playSuccessChime();
    closeRadialMenu();

    fetch(`https://${GetParentResourceName()}/thehunt_animations:radialPlay`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ label: label, bodyMode: bodyMode === 'upper' ? 'upper' : 'full' })
    }).catch(() => { });
  }

  // Обновление отображения активных и предпросматриваемых карточек
  function updateCardStates() {
    if (!animGrid) return;
    animGrid.querySelectorAll('.anim-card').forEach(card => {
      const isPlay = (playingLabel && card.dataset.label === playingLabel);
      const isPrev = (previewLabel && card.dataset.label === previewLabel);
      card.classList.toggle('is-playing', Boolean(isPlay));
      card.classList.toggle('is-previewing', Boolean(isPrev));
    });
  }


  // Закрытие окна с сохранением состояния категории и скролла
  function close() {
    if (appEl) appEl.classList.add('hidden');

    // Сохраняем состояние текущей категории и скролла
    savedCategory = activeCategory;
    if (animGrid) {
      categoryScrollPositions[activeCategory] = animGrid.scrollTop;
    }

    playingLabel = null;
    previewLabel = null;
    isWindowFocused = true;
    isMMBActive = false;
    if (windowEl) windowEl.classList.remove('is-unfocused');

    playUiSound(480, 'sine', 0.05, 0.03);

    fetch(`https://${GetParentResourceName()}/thehunt_animations:close`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(() => { });
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/[&<>"']/g, function (m) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];
    });
  }

  // Инициализация
  function init() {
    setupDragging();

    // Отслеживаем прокрутку сетки для сохранения позиции
    if (animGrid) {
      animGrid.addEventListener('scroll', () => {
        if (activeCategory) {
          categoryScrollPositions[activeCategory] = animGrid.scrollTop;
        }
      });
    }

    // Клик внутри окна меню возвращает его в полный фокус
    if (windowEl) {
      windowEl.addEventListener('mousedown', (e) => {
        if (e.button === 0 || e.button === 2) {
          setWindowFocusState(true);
        }
      });
    }

    // Клик за пределами окна переводит меню в полупрозрачный режим
    if (appEl) {
      appEl.addEventListener('mousedown', (e) => {
        if (e.target === appEl) {
          setWindowFocusState(false);
        }
      });
    }

    // Зажатие колесика мыши (СКМ) для свободного вращения камеры
    window.addEventListener('mousedown', (e) => {
      if (appEl.classList.contains('hidden')) return;
      if (e.button === 1) {
        e.preventDefault();
        isMMBActive = true;
        fetch(`https://${GetParentResourceName()}/thehunt_animations:setCameraRotationState`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ active: true })
        }).catch(() => { });
      }
    });

    window.addEventListener('mouseup', (e) => {
      if (appEl.classList.contains('hidden')) return;
      if (e.button === 1 || (isMMBActive && (e.buttons & 4) === 0)) {
        isMMBActive = false;
        fetch(`https://${GetParentResourceName()}/thehunt_animations:setCameraRotationState`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ active: false })
        }).catch(() => { });
      }
    });


    // Слушатель клика по вкладке Избранное
    if (tabFavorites) {
      tabFavorites.addEventListener('click', () => {
        playUiSound(650, 'sine', 0.06, 0.035);
        if (animGrid) {
          categoryScrollPositions[activeCategory] = animGrid.scrollTop;
        }
        activeCategory = 'Favorites';
        renderCategories();
        renderAnimations();
        setTimeout(() => {
          if (animGrid) {
            animGrid.scrollTop = categoryScrollPositions['Favorites'] || 0;
          }
        }, 0);
      });
    }

    // Слушатель сообщений от Lua
    window.addEventListener('message', (e) => {
      const data = e.data;
      if (!data) return;

      switch (data.type) {
        case 'Open':
          categories = data.categories || [];
          allAnimations = data.animations || [];
          pinnedList = data.pinned || [];
          bodyMode = data.bodyMode || 'full';

          isWindowFocused = true;
          isMMBActive = false;
          previewLabel = null;
          if (windowEl) windowEl.classList.remove('is-unfocused');

          // Восстанавливаем сохраненную категорию или Избранное
          if (savedCategory && (categories.some(c => c.id === savedCategory) || savedCategory === 'Favorites')) {
            activeCategory = savedCategory;
          } else {
            const favCount = allAnimations.filter(a => a.Favorite).length;
            if (favCount > 0) {
              activeCategory = 'Favorites';
            } else {
              activeCategory = 'All';
            }
          }

          // Режим тела
          btnModeFull.classList.toggle('active', bodyMode === 'full');
          btnModeUpper.classList.toggle('active', bodyMode === 'upper');

          // Сброс поиска
          if (searchInput) searchInput.value = '';
          searchQuery = '';
          if (btnClearSearch) btnClearSearch.classList.add('hidden');

          renderCategories();
          renderAnimations();

          // Восстанавливаем позицию скролла в сетке
          setTimeout(() => {
            if (animGrid && categoryScrollPositions[activeCategory] !== undefined) {
              animGrid.scrollTop = categoryScrollPositions[activeCategory];
            }
          }, 0);

          playUiSound(580, 'sine', 0.08, 0.03);
          if (appEl) appEl.classList.remove('hidden');
          break;

        case 'Close':
          close();
          break;

        case 'SyncPinned':
          pinnedList = data.pinned || [];
          renderAnimations();
          break;

        case 'OpenRadial':
          openRadialMenu(data.pinned || []);
          break;

        case 'CloseRadial':
          closeRadialMenu();
          break;


        case 'AnimationStarted':
          playingLabel = data.label || null;
          previewLabel = null;
          updateCardStates();
          break;

        case 'AnimationStopped':
          playingLabel = null;
          updateCardStates();
          break;

        case 'PreviewStarted':
          previewLabel = data.label || null;
          updateCardStates();
          break;

        case 'PreviewStopped':
          previewLabel = null;
          updateCardStates();
          break;
      }
    });

    // Кнопка закрытия
    if (btnClose) {
      btnClose.addEventListener('click', close);
    }

    // Кнопка остановки
    if (btnStopAnim) {
      btnStopAnim.addEventListener('click', stopAnimation);
    }

    // Переключатель режима тела
    if (btnModeFull) {
      btnModeFull.addEventListener('click', () => {
        playUiSound(650, 'sine', 0.06, 0.035);
        bodyMode = 'full';
        btnModeFull.classList.add('active');
        btnModeUpper.classList.remove('active');
      });
    }

    if (btnModeUpper) {
      btnModeUpper.addEventListener('click', () => {
        playUiSound(650, 'sine', 0.06, 0.035);
        bodyMode = 'upper';
        btnModeUpper.classList.add('active');
        btnModeFull.classList.remove('active');
      });
    }

    // Живой поиск
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        searchQuery = e.target.value;
        if (btnClearSearch) {
          btnClearSearch.classList.toggle('hidden', !searchQuery.trim());
        }
        renderAnimations();
      });
    }

    if (btnClearSearch) {
      btnClearSearch.addEventListener('click', () => {
        playUiSound(480, 'sine', 0.05, 0.03);
        if (searchInput) searchInput.value = '';
        searchQuery = '';
        btnClearSearch.classList.add('hidden');
        renderAnimations();
      });
    }

    // Отслеживание фокуса ввода для полной блокировки управления в RedM
    document.addEventListener('focusin', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        fetch(`https://${GetParentResourceName()}/thehunt_animations:setInputFocus`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ hasFocus: true })
        }).catch(() => { });
      }
    });

    document.addEventListener('focusout', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
        fetch(`https://${GetParentResourceName()}/thehunt_animations:setInputFocus`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ hasFocus: false })
        }).catch(() => { });
      }
    });

    // Клавиатурные события (Escape / F3 для выхода)
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' || e.key === 'Esc') {
        if (radialContainer && !radialContainer.classList.contains('hidden')) {
          e.preventDefault();
          closeRadialMenu();
          fetch(`https://${GetParentResourceName()}/thehunt_animations:radialClose`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
          }).catch(() => { });
          return;
        }
      }

      if (appEl.classList.contains('hidden')) return;

      const isInputActive = document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA');

      if ((e.key === 'z' || e.key === 'Z' || e.key === 'я' || e.key === 'Я') && !isInputActive) {
        e.preventDefault();
        stopAnimation();
        return;
      }

      if (e.key === 'Escape' || e.key === 'Esc' || e.key === 'F3') {
        e.preventDefault();
        close();
      }
    });
  }

  return { init };
})();

document.addEventListener('DOMContentLoaded', AnimUI.init);
