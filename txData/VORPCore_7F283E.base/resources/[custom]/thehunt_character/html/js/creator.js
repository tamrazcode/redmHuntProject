// =================================================================
// HUNT: Hard RP — Character Creator Controller
// Sims-Style Circular Dock + Modular Panel with State Preservation
// =================================================================

const CreatorUI = (function() {
  let activeGender = 'Male';
  let pedCustom = false;
  let activeTab = 'body';
  let activeClothingCategory = 'Shirt';
  let activeWardrobeGroup = 'tops';
  let configData = {};
  let isSubmitting = false;
  let creatorPanelDragBound = false;

  const NATIONS_LIST = [
    "Американец",
    "Индеец",
    "Ирландец",
    "Немец",
    "Англичанин",
    "Шотландец",
    "Француз",
    "Скандинав",
    "Итальянец",
    "Мексиканец",
    "Китаец",
    "Испанец"
  ];

  // The creator stores the selected form as the visible nation value.  Keep
  // both grammatical forms together so changing the body type also updates
  // an already selected nation instead of resetting the player's choice.
  const NATION_GENDER_FORMS = {
    "Американец": "Американка",
    "Индеец": "Индианка",
    "Ирландец": "Ирландка",
    "Немец": "Немка",
    "Англичанин": "Англичанка",
    "Шотландец": "Шотландка",
    "Француз": "Француженка",
    "Скандинав": "Скандинавка",
    "Итальянец": "Итальянка",
    "Мексиканец": "Мексиканка",
    "Китаец": "Китаянка",
    "Испанец": "Испанка"
  };

  const nationForGender = (nation, gender) => {
    const value = String(nation || 'Американец');
    for (const [male, female] of Object.entries(NATION_GENDER_FORMS)) {
      if (value === male || value === female) {
        return gender === 'Female' ? female : male;
      }
    }
    return value;
  };

  const capitaliseNameWord = (word) => {
    const value = String(word || '');
    return value ? value.charAt(0).toUpperCase() + value.slice(1).toLowerCase() : '';
  };

  // Keep the input in the exact "Имя Фамилия" shape while still allowing the
  // player to type the separator before the second word is entered.
  const normaliseFullName = (raw) => {
    let value = String(raw || '')
      .replace(/[^\u0400-\u04FF\-\s]/g, '')
      .replace(/\s+/g, ' ')
      .replace(/^ +/, '');
    const hasTrailingSeparator = value.endsWith(' ');
    const words = value.trim().split(' ').filter(Boolean).slice(0, 2);
    if (!words.length) return '';

    const first = capitaliseNameWord(words[0].slice(0, 20));
    if (words.length === 1) return first + (hasTrailingSeparator ? ' ' : '');
    return `${first} ${capitaliseNameWord(words[1].slice(0, 20))}`;
  };

  let maleState = null;
  let femaleState = null;

  let creatorState = {
    firstname: '',
    lastname: '',
    fullname: '',
    age: 25,
    nation: 'Американец',
    gender: 'Male',
    skin: {
      head: 0,
      eyes: 0,
      bodyBuild: 0,
      waist: 0,
      scale: 1.0,
      albedo: 0,
      features: {},
      overlays: {}
    },
    comps: {},
    compTints: {}
  };

  const creatorScreen = document.getElementById('creatorScreen');
  const creatorPanelTitle = document.getElementById('creatorPanelTitle');
  const creatorTabContent = document.getElementById('creatorTabContent');
  const btnGenderMale = document.getElementById('btnGenderMale');
  const btnGenderFemale = document.getElementById('btnGenderFemale');

  const TAB_TITLES = {
    body: 'Телосложение и рост',
    heritage: 'Тип лица, тон кожи, глаза и зубы',
    hair: 'Прическа и растительность',
    morphs: 'Скульптура черт лица',
    overlays: 'Особенности кожи и макияж',
    clothing: 'Гардероб и одежда',
    info: 'Информация о персонаже'
  };

  // The editor panel is intentionally movable so it never covers the part of
  // the character a player is editing.  The camera toolbar is a separate
  // element and is deliberately not included here.
  function setupCreatorPanelDragging() {
    if (creatorPanelDragBound) return;

    const panel = document.querySelector('.creator-panel');
    const handle = panel?.querySelector('.panel-header');
    if (!panel || !handle) return;

    let drag = null;
    const finishDrag = (event) => {
      if (!drag || (event && event.pointerId !== drag.pointerId)) return;
      if (handle.hasPointerCapture(drag.pointerId)) {
        handle.releasePointerCapture(drag.pointerId);
      }
      drag = null;
      panel.classList.remove('is-dragging');
      handle.classList.remove('is-dragging');
    };

    handle.addEventListener('pointerdown', (event) => {
      if (event.button !== 0 || creatorScreen.classList.contains('hidden')) return;
      if (event.target.closest('button, input, select, textarea, label, a')) return;

      const rect = panel.getBoundingClientRect();
      panel.style.position = 'fixed';
      panel.style.left = `${rect.left}px`;
      panel.style.top = `${rect.top}px`;
      panel.style.bottom = 'auto';
      panel.style.transform = 'none';

      drag = {
        pointerId: event.pointerId,
        offsetX: event.clientX - rect.left,
        offsetY: event.clientY - rect.top
      };
      handle.setPointerCapture(event.pointerId);
      panel.classList.add('is-dragging');
      handle.classList.add('is-dragging');
      event.preventDefault();
      event.stopPropagation();
    });

    handle.addEventListener('pointermove', (event) => {
      if (!drag || event.pointerId !== drag.pointerId) return;

      const rect = panel.getBoundingClientRect();
      const maxLeft = Math.max(0, window.innerWidth - rect.width);
      const maxTop = Math.max(0, window.innerHeight - rect.height);
      panel.style.left = `${Math.max(0, Math.min(maxLeft, event.clientX - drag.offsetX))}px`;
      panel.style.top = `${Math.max(0, Math.min(maxTop, event.clientY - drag.offsetY))}px`;
      event.preventDefault();
    });

    handle.addEventListener('pointerup', finishDrag);
    handle.addEventListener('pointercancel', finishDrag);
    creatorPanelDragBound = true;
  }

  function init() {
    setupCreatorPanelDragging();
    const heldCameraKeys = new Set();
    let cameraKeyTimer = null;
    const updateHeldCameraMotion = () => {
      if (cameraKeyTimer) {
        clearInterval(cameraKeyTimer);
        cameraKeyTimer = null;
      }
      if (!heldCameraKeys.size) return;
      cameraKeyTimer = setInterval(() => {
        const up = heldCameraKeys.has('up');
        const down = heldCameraKeys.has('down');
        if (up !== down) {
          fetch(`https://${GetParentResourceName()}/creator:moveCameraZ`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ delta: up ? 0.028 : -0.028 })
          }).catch(() => {});
        }
        const left = heldCameraKeys.has('left');
        const right = heldCameraKeys.has('right');
        if (left !== right) {
          fetch(`https://${GetParentResourceName()}/creator:rotatePed`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ delta: left ? 2.2 : -2.2 })
          }).catch(() => {});
        }
      }, 40);
    };
    // Sims Dock circular buttons
    document.querySelectorAll('.sims-circle-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const tab = e.currentTarget.dataset.tab;
        if (tab) switchTab(tab);
      });
    });

    // Back button in circular dock
    const btnDockBack = document.getElementById('btnDockBack');
    if (btnDockBack) {
      btnDockBack.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/creator:cancel`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        });
      });
    }

    // Gender switches
    btnGenderMale.addEventListener('click', () => setGender('Male'));
    btnGenderFemale.addEventListener('click', () => setGender('Female'));

    // Camera presets
    document.querySelectorAll('.btn-cam-preset').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('.btn-cam-preset').forEach(b => b.classList.remove('active'));
        e.currentTarget.classList.add('active');
        const preset = e.currentTarget.dataset.preset;
        fetch(`https://${GetParentResourceName()}/creator:setCameraPreset`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ preset: preset })
        });
      });
    });

    // Keyboard navigation (W, S, A, D, Arrow keys) when not typing in inputs
    window.addEventListener('keydown', (e) => {
      if (creatorScreen.classList.contains('hidden')) return;
      const focused = document.activeElement;
      const tag = focused ? focused.tagName.toLowerCase() : '';
      const inputType = focused && tag === 'input' ? (focused.type || '').toLowerCase() : '';
      if (tag === 'textarea' || tag === 'select' || (tag === 'input' && ['text', 'number', 'email', 'password'].includes(inputType))) return;

      const key = e.key.toLowerCase();
      if (key === 'a' || key === 'ф' || key === 'arrowleft') {
        e.preventDefault();
        heldCameraKeys.add('left');
        if (!e.repeat) updateHeldCameraMotion();
      } else if (key === 'd' || key === 'в' || key === 'arrowright') {
        e.preventDefault();
        heldCameraKeys.add('right');
        if (!e.repeat) updateHeldCameraMotion();
      } else if (key === 'w' || key === 'ц' || key === 'arrowup') {
        e.preventDefault();
        heldCameraKeys.add('up');
        if (!e.repeat) updateHeldCameraMotion();
      } else if (key === 's' || key === 'ы' || key === 'arrowdown') {
        e.preventDefault();
        heldCameraKeys.add('down');
        if (!e.repeat) updateHeldCameraMotion();
      }
    });
    window.addEventListener('keyup', (e) => {
      const key = e.key.toLowerCase();
      if (key === 'a' || key === 'ф' || key === 'arrowleft') heldCameraKeys.delete('left');
      if (key === 'd' || key === 'в' || key === 'arrowright') heldCameraKeys.delete('right');
      if (key === 'w' || key === 'ц' || key === 'arrowup') heldCameraKeys.delete('up');
      if (key === 's' || key === 'ы' || key === 'arrowdown') heldCameraKeys.delete('down');
      updateHeldCameraMotion();
    });
    window.addEventListener('blur', () => {
      heldCameraKeys.clear();
      updateHeldCameraMotion();
    });

    let isOrbiting = false;
    let lastOrbitX = 0;
    window.addEventListener('mousedown', (e) => {
      if (e.button !== 0 || creatorScreen.classList.contains('hidden')) return;
      if (e.target.closest('button, input, select, textarea, .creator-panel, .camera-toolbar')) return;
      isOrbiting = true;
      lastOrbitX = e.clientX;
    });
    window.addEventListener('mouseup', () => { isOrbiting = false; });
    window.addEventListener('mousemove', (e) => {
      if (!isOrbiting) return;
      const deltaX = e.clientX - lastOrbitX;
      lastOrbitX = e.clientX;
      if (Math.abs(deltaX) < 1) return;
      fetch(`https://${GetParentResourceName()}/creator:orbitCamera`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ delta: deltaX * 0.012 })
      });
    });
    window.addEventListener('wheel', (e) => {
      if (creatorScreen.classList.contains('hidden') || e.target.closest('.creator-panel')) return;
      e.preventDefault();
      fetch(`https://${GetParentResourceName()}/creator:zoomCamera`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ delta: e.deltaY > 0 ? 0.18 : -0.18 })
      });
    }, { passive: false });
  }

  function createDefaultState(gender) {
    const outfitKey = gender === 'Female' ? 'female' : 'male';
    const starterOutfit = configData.clothing?.DefaultOutfit?.[outfitKey] || {};
    const overlayConfig = configData.overlays || {};
    const browColours = overlayConfig.ColorPalettes?.eyebrows || [];
    const browPalette = overlayConfig.RendererPalettes?.eyebrows || 0;
    const hairList = gender === 'Female' ? (configData.hairs?.FemaleHairs || []) : (configData.hairs?.MaleHairs || []);
    const firstHair = hairList.find(item => Number(item.hash) !== 0 && Number(item.hash) !== -1);
    const firstHairHash = firstHair ? Number((firstHair.tints || [])[0] || firstHair.hash) : -1;
    return {
      firstname: '',
      lastname: '',
      fullname: '',
      age: 25,
      nation: nationForGender('Американец', gender),
      gender: gender,
      skin: {
        head: 0,
        headIndex: gender === 'Female' ? 1 : 8,
        toneId: 1,
        eyes: 0,
        bodyBuild: 0,
        buildIndex: 1,
        waist: 0,
        waistIndex: 1,
        scale: 1.0,
        albedo: 0,
        features: {},
        overlays: {
          eyebrows: {
            visibility: 1, tx_id: 1,
            tx_normal: 0, tx_material: 0, tx_color_type: 0,
            tx_opacity: 1.0, tx_unk: 0,
            palette: browPalette,
            palette_color_primary: browColours[0] || 0,
            palette_color_secondary: 0, palette_color_tertiary: 0,
            var: 1, opacity: 1.0
          }
        }
      },
      comps: { ...starterOutfit, Hair: firstHairHash },
      compTints: {}
    };
  }

  function open(data) {
    pedCustom = data.pedCustom === true;
    configData = (data && data.config) ? data.config : (data || {});
    activeGender = 'Male';
    activeTab = 'body';
    activeClothingCategory = 'Shirt';

    const btnBack = document.getElementById('btnDockBack');
    if (btnBack) {
      const isFirst = Boolean(data && (data.isFirst === true || data.isFirstCharacter === true || data.hasCharacters === false));
      btnBack.style.display = isFirst ? 'none' : '';
    }

    maleState = createDefaultState('Male');
    femaleState = createDefaultState('Female');
    creatorState = maleState;

    if (pedCustom && data.initialState) {
      const saved = data.initialState;
      activeGender = saved.gender === 'Female' ? 'Female' : 'Male';
      const skin = saved.skin || {};
      creatorState = { ...createDefaultState(activeGender), ...saved, skin: {
        headIndex: skin.HeadIndex, toneId: skin.ToneId, eyes: skin.Eyes,
        buildIndex: skin.BuildIndex, waistIndex: skin.WaistIndex || 1, scale: skin.Scale || 1,
        features: skin.features || {}, overlays: skin.overlays || {}
      } };
      if (activeGender === 'Female') femaleState = creatorState; else maleState = creatorState;
    }

    updateGenderButtons();
    switchTab('body');
    creatorScreen.classList.remove('hidden');
  }

  function close() {
    creatorScreen.classList.add('hidden');
    isSubmitting = false;
  }

  function submissionFailed(message) {
    isSubmitting = false;
    const btnFinish = document.getElementById('btnFinishCreator');
    if (btnFinish) {
      btnFinish.disabled = false;
      btnFinish.classList.add('ready');
      btnFinish.textContent = 'Создать персонажа';
    }
    const hint = document.getElementById('nameValidationHint');
    if (hint && message) {
      hint.style.color = '#ef4444';
      hint.textContent = message;
    }
  }

  function setGender(gender) {
    if (activeGender === gender) return;

    // Save previous gender customization state
    if (activeGender === 'Male') {
      maleState = JSON.parse(JSON.stringify(creatorState));
    } else {
      femaleState = JSON.parse(JSON.stringify(creatorState));
    }

    activeGender = gender;

    // Restore target gender customization state
    if (gender === 'Male') {
      creatorState = maleState || createDefaultState('Male');
    } else {
      creatorState = femaleState || createDefaultState('Female');
    }
    creatorState.gender = gender;
    creatorState.nation = nationForGender(creatorState.nation, gender);
    if (!creatorState.skin) creatorState.skin = {};

    updateGenderButtons();

    fetch(`https://${GetParentResourceName()}/creator:setGender`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ gender: gender })
    });

    renderCurrentTab();
  }

  function updateGenderButtons() {
    btnGenderMale.classList.toggle('active', activeGender === 'Male');
    btnGenderFemale.classList.toggle('active', activeGender === 'Female');
  }

  function switchTab(tabName) {
    if (activeTab === 'heritage' && tabName !== 'heritage') {
      fetch(`https://${GetParentResourceName()}/creator:previewTeeth`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: false })
      }).catch(() => {});
    }

    activeTab = tabName;
    const genderSwitch = document.querySelector('.gender-switch-container');
    if (genderSwitch) genderSwitch.classList.toggle('hidden', tabName !== 'body');
    document.querySelectorAll('.sims-circle-btn[data-tab]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });

    if (creatorPanelTitle) {
      creatorPanelTitle.textContent = TAB_TITLES[tabName] || 'Настройка персонажа';
    }

    renderCurrentTab();
  }

  function renderCurrentTab() {
    switch (activeTab) {
      case 'body':
        renderTabBody();
        break;
      case 'heritage':
        renderTabHeritage();
        break;
      case 'hair':
        renderTabHair();
        break;
      case 'morphs':
        renderTabMorphs();
        break;
      case 'overlays':
        renderTabOverlays();
        break;
      case 'clothing':
        renderTabClothing();
        break;
      case 'info':
        renderTabInfo();
        break;
    }
  }

  // =================================================================
  // Tab 1: Body Build, Waist & Height/Scale
  // =================================================================
  function renderTabBody() {
    const genderKey = activeGender === 'Female' ? 'female' : 'male';
    const appearance = configData.appearance || {};
    const builds = (appearance.BodyBuilds && appearance.BodyBuilds[genderKey]) || [];

    let buildsHtml = '';
    const activeBuildIdx = (creatorState.skin && creatorState.skin.buildIndex) ? creatorState.skin.buildIndex : 1;
    builds.forEach((b, idx) => {
      const isActive = (idx + 1) === activeBuildIdx;
      buildsHtml += `<div class="item-card ${isActive ? 'active' : ''}" data-build-idx="${idx + 1}"><span class="item-card-title">${b.name}</span></div>`;
    });

    const scaleVal = (creatorState.skin && creatorState.skin.scale) ? creatorState.skin.scale : 1.0;
    const scaleToHeight = (scale) => (1.75 * Number(scale)).toFixed(2);
    const torsoFeatures = ((appearance.FaceFeatures && appearance.FaceFeatures.upperbody) || [])
      .filter(feat => feat.id !== 'ChestS' || activeGender === 'Female');
    let torsoHtml = '';
    torsoFeatures.forEach(feat => {
      const curVal = creatorState.skin?.features?.[feat.id] ?? (feat.default || 0.0);
      const percent = Math.round(((curVal + 1.0) / 2.0) * 100);
      torsoHtml += `<div class="slider-container" data-feat="${feat.id}"><div class="slider-header"><span class="slider-label">${feat.label}</span><span class="slider-val-badge" id="badge_${feat.id}">${percent}%</span></div><div class="slider-row"><button class="btn-step btn-minus body-morph-step" data-target="${feat.id}">-</button><input type="range" class="hunt-slider body-morph-slider" id="slider_${feat.id}" min="-1.0" max="1.0" step="0.05" value="${curVal}" data-feat="${feat.id}"><button class="btn-step btn-plus body-morph-step" data-target="${feat.id}">+</button></div></div>`;
    });

    const legFeatures = (appearance.FaceFeatures && appearance.FaceFeatures.lowerbody) || [];
    let legsHtml = '';
    legFeatures.forEach(feat => {
      const curVal = creatorState.skin?.features?.[feat.id] ?? (feat.default || 0.0);
      const percent = Math.round(((curVal + 1.0) / 2.0) * 100);
      legsHtml += `<div class="slider-container" data-feat="${feat.id}"><div class="slider-header"><span class="slider-label">${feat.label}</span><span class="slider-val-badge" id="badge_${feat.id}">${percent}%</span></div><div class="slider-row"><button class="btn-step btn-minus body-morph-step" data-target="${feat.id}">-</button><input type="range" class="hunt-slider body-morph-slider" id="slider_${feat.id}" min="-1.0" max="1.0" step="0.05" value="${curVal}" data-feat="${feat.id}"><button class="btn-step btn-plus body-morph-step" data-target="${feat.id}">+</button></div></div>`;
    });

    creatorTabContent.innerHTML = `
      <div class="creator-section">
        <span class="section-title">Телосложение</span>
        <div class="items-grid" id="buildsGrid">${buildsHtml}</div>
      </div>

      <div class="creator-section">
        <span class="section-title">Размер талии</span>
        <div class="slider-container">
          <div class="slider-header">
            <span class="slider-label">Обхват талии</span>
            <span class="slider-val-badge" id="badge_waist">Размер 1</span>
          </div>
          <div class="slider-row">
            <button class="btn-step btn-minus" id="btnWaistMinus">-</button>
            <input type="range" class="hunt-slider" id="waistSlider" min="1" max="21" step="1" value="1">
            <button class="btn-step btn-plus" id="btnWaistPlus">+</button>
          </div>
        </div>
      </div>

      <div class="creator-section">
        <span class="section-title">Рост персонажа</span>
        <div class="slider-container">
          <div class="slider-header">
            <span class="slider-label">Шкала роста</span>
            <span class="slider-val-badge" id="badge_scale">${scaleToHeight(scaleVal)} м</span>
          </div>
          <div class="slider-row">
            <input type="range" class="hunt-slider" id="scaleSlider" min="0.828571" max="1.257143" step="0.001" value="${scaleVal}">
          </div>
        </div>
      </div>
      <div class="creator-section">
        <span class="section-title">Торс и плечи</span>
        ${torsoHtml}
      </div>
      <div class="creator-section" style="margin-top:8px;">
        <span class="section-title">Ноги и икры</span>
        ${legsHtml}
      </div>
    `;

    // Builds
    document.querySelectorAll('#buildsGrid .item-card').forEach(card => {
      card.addEventListener('click', (e) => {
        document.querySelectorAll('#buildsGrid .item-card').forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');
        const idx = parseInt(e.currentTarget.dataset.buildIdx);
        creatorState.skin.buildIndex = idx;
        fetch(`https://${GetParentResourceName()}/creator:setBodyBuild`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ buildIndex: idx })
        });
      });
    });

    // Waist
    const waistSlider = document.getElementById('waistSlider');
    const badgeWaist = document.getElementById('badge_waist');
    const updateWaist = (val) => {
      creatorState.skin.waistIndex = parseInt(val);
      badgeWaist.textContent = `Размер ${val}`;
      fetch(`https://${GetParentResourceName()}/creator:setWaist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ waistIndex: parseInt(val) })
      });
    };

    if (waistSlider) {
      waistSlider.addEventListener('input', (e) => updateWaist(e.target.value));
      document.getElementById('btnWaistMinus').addEventListener('click', () => {
        let v = Math.max(1, parseInt(waistSlider.value) - 1);
        waistSlider.value = v;
        updateWaist(v);
      });
      document.getElementById('btnWaistPlus').addEventListener('click', () => {
        let v = Math.min(21, parseInt(waistSlider.value) + 1);
        waistSlider.value = v;
        updateWaist(v);
      });
    }

    // Scale
    document.getElementById('scaleSlider').addEventListener('input', (e) => {
      const s = parseFloat(e.target.value);
      creatorState.skin.scale = s;
      document.getElementById('badge_scale').textContent = `${scaleToHeight(s)} м`;
      fetch(`https://${GetParentResourceName()}/creator:setScale`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scale: s })
      });
    });

    const updateBodyMorph = (slider) => {
      const featId = slider.dataset.feat;
      const val = parseFloat(slider.value);
      creatorState.skin.features = creatorState.skin.features || {};
      creatorState.skin.features[featId] = val;
      document.getElementById(`badge_${featId}`).textContent = `${Math.round(((val + 1.0) / 2.0) * 100)}%`;
      fetch(`https://${GetParentResourceName()}/creator:setFeature`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ featureId: featId, value: val }) });
    };
    document.querySelectorAll('.body-morph-slider').forEach(slider => slider.addEventListener('input', () => updateBodyMorph(slider)));
    document.querySelectorAll('.body-morph-step').forEach(btn => btn.addEventListener('click', (e) => {
      const slider = document.getElementById(`slider_${e.currentTarget.dataset.target}`);
      if (!slider) return;
      slider.value = e.currentTarget.classList.contains('btn-plus') ? Math.min(1, Number(slider.value) + .05) : Math.max(-1, Number(slider.value) - .05);
      updateBodyMorph(slider);
    }));
  }

  // =================================================================
  // Tab 2: Heritage, Skin Tone, Eyes & Teeth
  // =================================================================
  function renderTabHeritage() {
    const genderKey = activeGender === 'Female' ? 'female' : 'male';
    const appearance = configData.appearance || {};
    const heads = (appearance.Heads && appearance.Heads[genderKey]) || [];
    const eyes = (appearance.EyeColors && appearance.EyeColors[genderKey]) || [];
    const skinTones = appearance.SkinTones || [];
    const teeth = (appearance.Teeth && appearance.Teeth[genderKey]) || [];

    let tonesHtml = '';
    skinTones.forEach((st, idx) => {
      const isActive = Number(creatorState.skin.toneId || 1) === Number(st.id);
      tonesHtml += `<div class="item-card ${isActive ? 'active' : ''}" data-tone-id="${st.id}"><span class="item-card-title">${st.label}</span></div>`;
    });

    let headsHtml = '';
    heads.forEach((h, idx) => {
      const isActive = (creatorState.skin.headIndex === h.id) || (idx === 0 && !creatorState.skin.headIndex);
      // Use the sparse native index to avoid uint32 sign issues with hashes.
      headsHtml += `<div class="item-card ${isActive ? 'active' : ''}" data-head-index="${h.id}"><span class="item-card-title">${h.label}</span></div>`;
    });

    let eyesHtml = '';
    eyes.forEach((eye, index) => {
      const isActive = Number(creatorState.skin.eyes) === Number(eye.hash)
        || (index === 0 && !creatorState.skin.eyes);
      eyesHtml += `<div class="swatch-item ${isActive ? 'active' : ''}" data-eye-hash="${eye.hash}" title="${eye.label}" style="background:${eye.hex}"></div>`;
    });

    let teethHtml = '';
    teeth.forEach((t, idx) => {
      const isActive = Number(creatorState.comps.Teeth || teeth[0]?.hash) === Number(t.hash);
      teethHtml += `<div class="item-card ${isActive ? 'active' : ''}" data-teeth="${t.hash}"><span class="item-card-title">${t.label}</span></div>`;
    });

    creatorTabContent.innerHTML = `
      <div class="creator-section">
        <span class="section-title">Цвет кожи / Тон</span>
        <div class="items-grid" id="skinTonesGrid">${tonesHtml}</div>
      </div>

      <div class="creator-section">
        <span class="section-title">Тип лица / Наследие</span>
        <div class="items-grid" id="headsGrid">${headsHtml}</div>
      </div>

      <div class="creator-section">
        <span class="section-title">Цвет глаз</span>
        <div class="swatches-grid" id="eyesSwatchesGrid">${eyesHtml}</div>
      </div>

      <div class="creator-section">
        <span class="section-title">Состояние зубов</span>
        <div class="items-grid" id="teethGrid">${teethHtml}</div>
      </div>
    `;

    document.querySelectorAll('#skinTonesGrid .item-card').forEach(card => {
      card.addEventListener('click', (e) => {
        document.querySelectorAll('#skinTonesGrid .item-card').forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');
        const toneId = parseInt(e.currentTarget.dataset.toneId);
        creatorState.skin.toneId = toneId;
        fetch(`https://${GetParentResourceName()}/creator:setSkinTone`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ toneId: toneId })
        });
      });
    });

    document.querySelectorAll('#headsGrid .item-card').forEach(card => {
      card.addEventListener('click', (e) => {
        document.querySelectorAll('#headsGrid .item-card').forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');
        // Send the native component index; Lua validates it against the registry.
        const headIndex = parseInt(e.currentTarget.dataset.headIndex);
        creatorState.skin.headIndex = headIndex;
        fetch(`https://${GetParentResourceName()}/creator:setHead`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ headIndex: headIndex })
        });
      });
    });

    document.querySelectorAll('#eyesSwatchesGrid .swatch-item').forEach(swatch => {
      swatch.addEventListener('click', (e) => {
        document.querySelectorAll('#eyesSwatchesGrid .swatch-item').forEach(node => node.classList.remove('active'));
        e.currentTarget.classList.add('active');
        const eyeHash = Number(e.currentTarget.dataset.eyeHash);
        creatorState.skin.eyes = eyeHash;
        fetch(`https://${GetParentResourceName()}/creator:setEyes`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ eyeHash })
        });
      });
    });

    document.querySelectorAll('#teethGrid .item-card').forEach(card => {
      card.addEventListener('click', (e) => {
        document.querySelectorAll('#teethGrid .item-card').forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');
        const hash = parseInt(e.currentTarget.dataset.teeth);
        creatorState.comps.Teeth = hash;
        fetch(`https://${GetParentResourceName()}/creator:setTeeth`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ teethHash: hash })
        });
      });
    });
  }

  // =================================================================
  // Tab 3: Hair & Beard
  // =================================================================
  function renderTabHair() {
    const hairsData = configData.hairs || {};
    const overlayConfig = configData.overlays || {};
    const hairsList = activeGender === 'Female' ? (hairsData.FemaleHairs || []) : (hairsData.MaleHairs || []);
    const beardsList = activeGender === 'Male' ? (hairsData.MaleBeards || []) : [];
    const swatches = hairsData.ColorSwatches || [];
    const browEntries = (overlayConfig.Info || {}).eyebrows || [];
    const browPalettes = (overlayConfig.ColorPalettes || {}).eyebrows || [];
    const browSwatchData = (overlayConfig.BrowSwatches || []).map(item => ({
      ...item, hash: Number(item.hash)
    }));

    const selectedTintIndex = (items, selectedHash) => {
      for (const item of items) {
        const index = (item.tints || []).indexOf(selectedHash);
        if (index >= 0) return index;
      }
      return -1;
    };
    const hairTintIndex = creatorState.hairTintIndex ?? selectedTintIndex(hairsList, creatorState.comps.Hair);
    const beardTintIndex = creatorState.beardTintIndex ?? selectedTintIndex(beardsList, creatorState.comps.Beard);
    const buildSwatches = (selectedIndex, dataKey) => swatches.map((swatch, index) =>
      `<div class="swatch-item ${Number(selectedIndex) === index ? 'active' : ''}" data-${dataKey}="${index}" title="${swatch.name}" style="background:${swatch.hex}"></div>`
    ).join('');
    const hairSwatchesHtml = buildSwatches(hairTintIndex, 'hair-tint');
    const beardSwatchesHtml = buildSwatches(beardTintIndex, 'beard-tint');

    let hairsHtml = '';
    hairsList.forEach(h => {
      const isActive = (creatorState.comps.Hair === h.hash) || (h.tints && h.tints.includes(creatorState.comps.Hair));
      hairsHtml += `<div class="item-card ${isActive ? 'active' : ''}" data-hair-id="${h.id}" data-hair-hash="${h.hash}"><span class="item-card-title">${h.name}</span></div>`;
    });

    let beardsHtml = '';
    if (activeGender === 'Male') {
      beardsList.forEach(b => {
        const isActive = (creatorState.comps.Beard === b.hash) || (b.tints && b.tints.includes(creatorState.comps.Beard));
        beardsHtml += `<div class="item-card ${isActive ? 'active' : ''}" data-beard-id="${b.id}" data-beard-hash="${b.hash}"><span class="item-card-title">${b.name}</span></div>`;
      });
    }

    creatorTabContent.innerHTML = `
      <div class="creator-section">
        <span class="section-title">Прическа</span>
        <div class="items-grid" id="hairGrid">${hairsHtml}</div>
      </div>

      <div class="creator-section">
        <span class="section-title">Цвет волос и растительности</span>
        <div class="swatches-grid" id="hairSwatchesGrid">${hairSwatchesHtml}</div>
      </div>

      ${activeGender === 'Male' ? `
        <div class="creator-section">
          <span class="section-title">Борода и усы</span>
          <div class="items-grid" id="beardGrid">${beardsHtml}</div>
        </div>
        <div class="creator-section">
          <span class="section-title">Цвет бороды и усов</span>
          <div class="swatches-grid" id="beardSwatchesGrid">${beardSwatchesHtml}</div>
        </div>
      ` : ''}
    `;

    // Brows are technically head overlays, but keeping them with hair makes
    // colouring and facial-hair editing predictable for the player.
    const savedBrows = ((creatorState.skin.overlays || {}).eyebrows) || {};
    const browRendererPalette = (overlayConfig.RendererPalettes || {}).eyebrows || 0;
    const activeBrow = savedBrows.visibility ? Number(savedBrows.tx_id || 0) : 0;
    const browOpacity = Math.max(0, Math.min(1, Number(savedBrows.opacity ?? 1)));
    const browCards = [`<div class="item-card ${activeBrow === 0 ? 'active' : ''}" data-brow="0"><span class="item-card-title">Без бровей</span></div>`]
      .concat(browEntries.map((item, index) => `<div class="item-card ${activeBrow === index + 1 ? 'active' : ''}" data-brow="${index + 1}"><span class="item-card-title">${item.label || `Брови ${index + 1}`}</span></div>`)).join('');
    const browSwatches = browSwatchData.map(item => {
      const isActive = Number(savedBrows.palette_color_primary) === Number(item.hash);
      return `<div class="swatch-item ${isActive ? 'active' : ''}" data-brow-colour="${item.hash}" title="${item.name}" style="background:${item.hex}"></div>`;
    }).join('');
    creatorTabContent.insertAdjacentHTML('beforeend', `
      <div class="creator-section">
        <span class="section-title">Брови</span>
        <div class="items-grid" id="browGrid">${browCards}</div>
        <div class="swatches-grid" id="browSwatchesGrid" style="margin-top:8px">${browSwatches}</div>
        <div class="slider-container" style="margin-top:10px">
          <div class="slider-header"><span class="slider-label">Насыщенность бровей</span><span class="slider-val-badge" id="badge_browOpacity">${Math.round(browOpacity * 100)}%</span></div>
          <div class="slider-row">
            <button class="btn-step btn-minus" id="btnBrowMinus">-</button>
            <input type="range" class="hunt-slider" id="browOpacitySlider" min="0" max="1" step="0.05" value="${browOpacity}">
            <button class="btn-step btn-plus" id="btnBrowPlus">+</button>
          </div>
        </div>
      </div>`);

    const applyBrows = (txId, colour, opacity) => {
      if (!creatorState.skin.overlays) creatorState.skin.overlays = {};
      const current = creatorState.skin.overlays.eyebrows || {};
      const finalOpacity = Math.max(0, Math.min(1, Number(opacity ?? current.opacity ?? 1)));
      creatorState.skin.overlays.eyebrows = {
        ...current, visibility: txId > 0 ? 1 : 0, tx_id: txId,
        tx_normal: 0, tx_material: 0, tx_color_type: 0, tx_opacity: 1.0,
        tx_unk: 0, palette: browRendererPalette,
        palette_color_primary: colour || browPalettes[0] || 0,
        palette_color_secondary: 0, palette_color_tertiary: 0,
        var: 1, opacity: finalOpacity
      };
      fetch(`https://${GetParentResourceName()}/creator:setOverlay`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'eyebrows', overlay: creatorState.skin.overlays.eyebrows })
      });
    };
    document.querySelectorAll('#browGrid .item-card').forEach(card => card.addEventListener('click', (e) => {
      document.querySelectorAll('#browGrid .item-card').forEach(node => node.classList.remove('active'));
      e.currentTarget.classList.add('active');
      applyBrows(Number(e.currentTarget.dataset.brow), (creatorState.skin.overlays.eyebrows || {}).palette_color_primary || savedBrows.palette_color_primary);
    }));
    document.querySelectorAll('#browSwatchesGrid .swatch-item').forEach(swatch => swatch.addEventListener('click', (e) => {
      document.querySelectorAll('#browSwatchesGrid .swatch-item').forEach(node => node.classList.remove('active'));
      e.currentTarget.classList.add('active');
      const current = creatorState.skin.overlays.eyebrows || savedBrows;
      applyBrows(Number(current.tx_id || 0), Number(e.currentTarget.dataset.browColour), Number(current.opacity ?? 1));
    }));
    const browSlider = document.getElementById('browOpacitySlider');
    if (browSlider) {
      browSlider.addEventListener('input', (e) => {
        const opacity = Number(e.target.value);
        document.getElementById('badge_browOpacity').textContent = `${Math.round(opacity * 100)}%`;
        const current = creatorState.skin.overlays.eyebrows || savedBrows;
        applyBrows(Number(current.tx_id || 0), Number(current.palette_color_primary || browPalettes[0] || 0), opacity);
      });
      document.getElementById('btnBrowMinus')?.addEventListener('click', () => {
        browSlider.value = Math.max(0, Number(browSlider.value) - 0.05);
        browSlider.dispatchEvent(new Event('input'));
      });
      document.getElementById('btnBrowPlus')?.addEventListener('click', () => {
        browSlider.value = Math.min(1, Number(browSlider.value) + 0.05);
        browSlider.dispatchEvent(new Event('input'));
      });
    }

    const applyHairTint = (tintIdx) => {
        creatorState.hairTintIndex = tintIdx;
        const activeHair = document.querySelector('#hairGrid .item-card.active');
        if (activeHair) {
          const hairId = parseInt(activeHair.dataset.hairId);
          const item = hairsList.find(h => h.id === hairId);
          if (item && item.tints && item.tints.length > 0) {
            const tintHash = item.tints[tintIdx] ?? item.tints[Math.min(tintIdx, item.tints.length - 1)] ?? item.tints[0];
            if (tintHash) {
              creatorState.comps.Hair = tintHash;
              fetch(`https://${GetParentResourceName()}/creator:setHair`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ hash: tintHash })
              });
            }
          }
        }
    };
    document.querySelectorAll('#hairSwatchesGrid .swatch-item').forEach(swatch => {
      swatch.addEventListener('click', (e) => {
        const tintIdx = Number(e.currentTarget.dataset.hairTint);
        document.querySelectorAll('#hairSwatchesGrid .swatch-item').forEach(node => node.classList.remove('active'));
        e.currentTarget.classList.add('active');
        applyHairTint(tintIdx);
      });
    });

    // Beard colour is independent from hair colour
    const applyBeardTint = (tintIdx) => {
        const activeBeard = document.querySelector('#beardGrid .item-card.active');
        creatorState.beardTintIndex = tintIdx;
        if (!activeBeard) return;
        const item = beardsList.find(b => b.id === parseInt(activeBeard.dataset.beardId));
        if (!item || !item.tints || item.tints.length === 0) return;
        const tintHash = item.tints[tintIdx] ?? item.tints[Math.min(tintIdx, item.tints.length - 1)] ?? item.tints[0];
        if (!tintHash) return;
        creatorState.comps.Beard = tintHash;
        fetch(`https://${GetParentResourceName()}/creator:setBeard`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ hash: tintHash })
        });
    };
    document.querySelectorAll('#beardSwatchesGrid .swatch-item').forEach(swatch => {
      swatch.addEventListener('click', (e) => {
        const tintIdx = Number(e.currentTarget.dataset.beardTint);
        document.querySelectorAll('#beardSwatchesGrid .swatch-item').forEach(node => node.classList.remove('active'));
        e.currentTarget.classList.add('active');
        applyBeardTint(tintIdx);
      });
    });

    // Hair clicks
    document.querySelectorAll('#hairGrid .item-card').forEach(card => {
      card.addEventListener('click', (e) => {
        document.querySelectorAll('#hairGrid .item-card').forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');
        const item = hairsList.find(h => h.id === parseInt(e.currentTarget.dataset.hairId));
        let hash = parseInt(e.currentTarget.dataset.hairHash);
        if (item && item.tints && item.tints.length > 0) {
          const tintIdx = creatorState.hairTintIndex || 0;
          hash = item.tints[tintIdx] ?? item.tints[Math.min(tintIdx, item.tints.length - 1)] ?? item.tints[0] ?? hash;
        }
        creatorState.comps.Hair = hash;
        fetch(`https://${GetParentResourceName()}/creator:setHair`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ hash: hash })
        });
      });
    });

    // Beard clicks
    if (activeGender === 'Male') {
      document.querySelectorAll('#beardGrid .item-card').forEach(card => {
        card.addEventListener('click', (e) => {
          document.querySelectorAll('#beardGrid .item-card').forEach(c => c.classList.remove('active'));
          e.currentTarget.classList.add('active');
          const item = beardsList.find(b => b.id === parseInt(e.currentTarget.dataset.beardId));
          let hash = parseInt(e.currentTarget.dataset.beardHash);
          if (item && item.tints && item.tints.length > 0) {
            const tintIdx = creatorState.beardTintIndex || 0;
            hash = item.tints[tintIdx] ?? item.tints[Math.min(tintIdx, item.tints.length - 1)] ?? item.tints[0] ?? hash;
          }
          creatorState.comps.Beard = hash;
          fetch(`https://${GetParentResourceName()}/creator:setBeard`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ hash: hash })
          });
        });
      });
    }
  }

  // =================================================================
  // Tab 4: Face Feature Morphs
  // =================================================================
  function renderTabMorphs() {
    const appearance = configData.appearance || {};
    const featuresMap = appearance.FaceFeatures || {};
    let html = '';

    const categoryLabels = {
      head: 'Форма головы и шеи',
      eyesandbrows: 'Глаза и брови',
      nose: 'Нос и переносица',
      mouthandlips: 'Рот и губы',
      jaw: 'Челюсть',
      chin: 'Подбородок',
      cheek: 'Скулы и щеки',
      ears: 'Уши'
    };

    for (const [catKey, featList] of Object.entries(featuresMap)) {
      if (catKey === 'upperbody' || catKey === 'lowerbody') continue;
      const catTitle = categoryLabels[catKey] || catKey;
      let slidersHtml = '';

      featList.forEach(feat => {
        const curVal = (creatorState.skin && creatorState.skin.features && creatorState.skin.features[feat.id] !== undefined) ? creatorState.skin.features[feat.id] : (feat.default || 0.0);
        const percent = Math.round(((curVal + 1.0) / 2.0) * 100);

        slidersHtml += `
          <div class="slider-container" data-feat="${feat.id}">
            <div class="slider-header">
              <span class="slider-label">${feat.label}</span>
              <span class="slider-val-badge" id="badge_${feat.id}">${percent}%</span>
            </div>
            <div class="slider-row">
              <button class="btn-step btn-minus" data-target="${feat.id}">-</button>
              <input type="range" class="hunt-slider morph-slider" id="slider_${feat.id}" min="-1.0" max="1.0" step="0.05" value="${curVal}" data-feat="${feat.id}">
              <button class="btn-step btn-plus" data-target="${feat.id}">+</button>
            </div>
          </div>
        `;
      });

      html += `
        <div class="creator-section">
          <span class="section-title">${catTitle}</span>
          ${slidersHtml}
        </div>
      `;
    }

    creatorTabContent.innerHTML = html;

    // Attach slider listeners
    document.querySelectorAll('.morph-slider').forEach(slider => {
      slider.addEventListener('input', (e) => {
        const featId = e.target.dataset.feat;
        const val = parseFloat(e.target.value);
        if (!creatorState.skin.features) creatorState.skin.features = {};
        creatorState.skin.features[featId] = val;
        const percent = Math.round(((val + 1.0) / 2.0) * 100);
        document.getElementById(`badge_${featId}`).textContent = `${percent}%`;

        fetch(`https://${GetParentResourceName()}/creator:setFeature`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ featureId: featId, value: val })
        });
      });
    });

    // Step buttons
    document.querySelectorAll('.btn-step').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const featId = e.currentTarget.dataset.target;
        const isPlus = e.currentTarget.classList.contains('btn-plus');
        const slider = document.getElementById(`slider_${featId}`);
        if (!slider) return;
        let cur = parseFloat(slider.value);
        cur = isPlus ? Math.min(1.0, cur + 0.05) : Math.max(-1.0, cur - 0.05);
        slider.value = cur;
        slider.dispatchEvent(new Event('input'));
      });
    });
  }

  // =================================================================
  // Tab 5: Overlays / Makeup / Imperfections
  // =================================================================
  function renderTabOverlays() {
    const overlaysData = configData.overlays || {};
    const layers = overlaysData.Layers || [];
    const layerSwatches = overlaysData.LayerSwatches || {};
    let html = '';

    layers.forEach(layer => {
      const infoList = (overlaysData.Info && overlaysData.Info[layer.name]) || [];
      const savedOverlay = (creatorState.skin.overlays || {})[layer.name];
      const selectedTx = savedOverlay && savedOverlay.visibility ? Number(savedOverlay.tx_id || 0) : 0;
      const savedOpacity = savedOverlay ? Number(savedOverlay.opacity ?? 1.0) : 1.0;
      const selectedColor = savedOverlay ? Number(savedOverlay.palette_color_primary || 0) : 0;
      const swatches = layerSwatches[layer.name] || [];

      let cardsHtml = `<div class="item-card ${selectedTx === 0 ? 'active' : ''}" data-layer="${layer.name}" data-tx="0"><span class="item-card-title">Отсутствует</span></div>`;
      infoList.forEach((info, idx) => {
        const txId = idx + 1;
        cardsHtml += `<div class="item-card ${selectedTx === txId ? 'active' : ''}" data-layer="${layer.name}" data-tx="${txId}"><span class="item-card-title">${info.label}</span></div>`;
      });

      let swatchesHtml = '';
      if (layer.hasPalette && swatches.length > 0) {
        const swatchItems = swatches.map((item, index) => {
          const isActive = (selectedColor === Number(item.hash)) || (selectedColor === 0 && index === 0);
          return `<div class="swatch-item ${isActive ? 'active' : ''}" data-layer="${layer.name}" data-overlay-color="${item.hash}" title="${item.name}" style="background:${item.hex}"></div>`;
        }).join('');
        swatchesHtml = `
          <div class="creator-section" style="margin-top:6px;">
            <span class="section-title">Цвет</span>
            <div class="swatches-grid" id="overlaySwatches_${layer.name}">${swatchItems}</div>
          </div>
        `;
      }

      html += `
        <div class="creator-section">
          <span class="section-title">${layer.label}</span>
          <div class="items-grid" id="overlayGrid_${layer.name}">${cardsHtml}</div>
          ${swatchesHtml}
          <div class="slider-container" style="margin-top: 6px;">
            <div class="slider-header">
              <span class="slider-label">Насыщенность</span>
              <span class="slider-val-badge" id="badge_op_${layer.name}">${Math.round(savedOpacity * 100)}%</span>
            </div>
            <div class="slider-row">
              <button class="btn-step btn-minus overlay-op-step" data-target="${layer.name}">-</button>
              <input type="range" class="hunt-slider overlay-opacity-slider" id="op_slider_${layer.name}" data-layer="${layer.name}" min="0.0" max="1.0" step="0.05" value="${savedOpacity}">
              <button class="btn-step btn-plus overlay-op-step" data-target="${layer.name}">+</button>
            </div>
          </div>
        </div>
      `;
    });

    creatorTabContent.innerHTML = html;

    // Overlay variation cards
    document.querySelectorAll('.creator-section .item-card[data-layer]').forEach(card => {
      card.addEventListener('click', (e) => {
        const layerName = e.currentTarget.dataset.layer;
        const txId = parseInt(e.currentTarget.dataset.tx);
        const layerConfig = layers.find(entry => entry.name === layerName) || {};
        
        document.querySelectorAll(`#overlayGrid_${layerName} .item-card`).forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');

        if (!creatorState.skin.overlays) creatorState.skin.overlays = {};
        const swatches = layerSwatches[layerName] || [];
        const rendererPalette = (overlaysData.RendererPalettes || {})[layerName] || 0;
        const defaultColor = swatches[0]?.hash || 0;

        if (!creatorState.skin.overlays[layerName]) {
          creatorState.skin.overlays[layerName] = {
            visibility: (txId === 0 ? 0 : 1), tx_id: txId,
            tx_normal: 0, tx_material: 0,
            tx_color_type: layerConfig.tx_color_type || 0, tx_opacity: 1.0, tx_unk: 0,
            palette: rendererPalette, palette_color_primary: defaultColor,
            palette_color_secondary: 0, palette_color_tertiary: 0,
            var: 1, opacity: 1.0
          };
        } else {
          creatorState.skin.overlays[layerName].tx_id = txId;
          creatorState.skin.overlays[layerName].visibility = (txId === 0 ? 0 : 1);
          creatorState.skin.overlays[layerName].tx_normal = 0;
          creatorState.skin.overlays[layerName].tx_color_type = layerConfig.tx_color_type || 0;
          if (layerConfig.hasPalette && !creatorState.skin.overlays[layerName].palette_color_primary) {
            creatorState.skin.overlays[layerName].palette_color_primary = defaultColor;
          }
        }

        fetch(`https://${GetParentResourceName()}/creator:setOverlay`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: layerName, overlay: creatorState.skin.overlays[layerName] })
        });
      });
    });

    // Swatches click
    document.querySelectorAll('.swatch-item[data-overlay-color]').forEach(swatch => {
      swatch.addEventListener('click', (e) => {
        const layerName = e.currentTarget.dataset.layer;
        const colorHash = Number(e.currentTarget.dataset.overlayColor);
        document.querySelectorAll(`#overlaySwatches_${layerName} .swatch-item`).forEach(s => s.classList.remove('active'));
        e.currentTarget.classList.add('active');

        if (!creatorState.skin.overlays) creatorState.skin.overlays = {};
        if (!creatorState.skin.overlays[layerName]) {
          creatorState.skin.overlays[layerName] = {
            visibility: 1, tx_id: 1,
            tx_normal: 0, tx_material: 0, tx_color_type: 0, tx_opacity: 1.0, tx_unk: 0,
            palette: (overlaysData.RendererPalettes || {})[layerName] || 0,
            palette_color_primary: colorHash,
            palette_color_secondary: 0, palette_color_tertiary: 0,
            var: 1, opacity: 1.0
          };
        } else {
          creatorState.skin.overlays[layerName].palette_color_primary = colorHash;
        }

        fetch(`https://${GetParentResourceName()}/creator:setOverlay`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: layerName, overlay: creatorState.skin.overlays[layerName] })
        });
      });
    });

    // Opacity sliders
    document.querySelectorAll('.overlay-opacity-slider').forEach(slider => {
      slider.addEventListener('input', (e) => {
        const layerName = e.target.dataset.layer;
        const op = parseFloat(e.target.value);
        document.getElementById(`badge_op_${layerName}`).textContent = `${Math.round(op * 100)}%`;

        if (!creatorState.skin.overlays) creatorState.skin.overlays = {};
        if (creatorState.skin.overlays[layerName]) {
          creatorState.skin.overlays[layerName].opacity = op;
          fetch(`https://${GetParentResourceName()}/creator:setOverlay`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: layerName, overlay: creatorState.skin.overlays[layerName] })
          });
        }
      });
    });

    // Step buttons
    document.querySelectorAll('.overlay-op-step').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const layerName = e.currentTarget.dataset.target;
        const isPlus = e.currentTarget.classList.contains('btn-plus');
        const slider = document.getElementById(`op_slider_${layerName}`);
        if (!slider) return;
        let cur = parseFloat(slider.value);
        cur = isPlus ? Math.min(1.0, cur + 0.05) : Math.max(0.0, cur - 0.05);
        slider.value = cur;
        slider.dispatchEvent(new Event('input'));
      });
    });
  }

  // =================================================================
  // Tab 6: Wardrobe / Clothing (Grouped Navigation, Models & Color Variations)
  // =================================================================
  function renderTabClothing(preserveScroll = false) {
    const prevTabScroll = creatorTabContent ? creatorTabContent.scrollTop : 0;
    const prevGrid = document.getElementById('clothingGrid');
    const prevGridScroll = prevGrid ? prevGrid.scrollTop : 0;

    const genderKey = activeGender === 'Female' ? 'Female' : 'Male';
    const clothingData = configData.clothing || {};
    const wardrobe = clothingData[genderKey] || {};

    const WARDROBE_GROUPS = [
      { id: 'tops', label: 'Верх', cats: ['Shirt', 'Vest', 'Coat', 'CoatClosed', 'Poncho', 'Cloak', 'Dress'] },
      { id: 'bottoms', label: 'Низ', cats: ['Pant', 'Skirt', 'Chap', 'Boots', 'Spurs', 'Spats'] },
      { id: 'head', label: 'Голова', cats: ['Hat', 'Mask', 'EyeWear', 'NeckWear', 'NeckTies'] },
      { id: 'accessories', label: 'Детали', cats: ['Gunbelt', 'Holster', 'Belt', 'Suspender', 'Glove', 'Gauntlets', 'Accessories', 'Bracelet', 'RingLh', 'RingRh', 'Satchels'] }
    ];

    const CATEGORY_NAMES = {
      Hat: 'Шляпы',
      Mask: 'Маски / Платки',
      EyeWear: 'Очки / Монокли',
      NeckWear: 'Платки на шею',
      NeckTies: 'Галстуки',
      Shirt: 'Рубахи',
      Vest: 'Жилеты',
      Coat: 'Пальто / Куртки',
      CoatClosed: 'Закрытые пальто',
      Poncho: 'Пончо',
      Cloak: 'Накидки',
      Dress: 'Платья',
      Pant: 'Штаны',
      Skirt: 'Юбки',
      Chap: 'Чапы',
      Boots: 'Сапоги / Обувь',
      Spurs: 'Шпоры',
      Spats: 'Гетры / Краги',
      Belt: 'Ремни',
      Gunbelt: 'Оружейные пояса',
      Holster: 'Кобуры',
      Suspender: 'Подтяжки',
      Glove: 'Перчатки',
      Gauntlets: 'Наручи',
      Accessories: 'Украшения',
      Bracelet: 'Браслеты',
      RingLh: 'Кольца (Л)',
      RingRh: 'Кольца (П)',
      Satchels: 'Сумки'
    };

    const CATEGORY_ICONS = {
      Hat: '<svg viewBox="0 0 24 24"><path d="M4 14h16M7 14c.4-5 2.2-8 5-8s4.6 3 5 8M3 17h18"/></svg>',
      Mask: '<svg viewBox="0 0 24 24"><path d="M4 10a8 8 0 0 1 16 0c0 5-4 9-8 9s-8-4-8-9ZM9 9h.01M15 9h.01"/></svg>',
      EyeWear: '<svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="3"/><circle cx="18" cy="12" r="3"/><path d="M9 12h6M3 12h-.5M21 12h.5"/></svg>',
      NeckWear: '<svg viewBox="0 0 24 24"><path d="M8 4c0 4 2 6 4 6s4-2 4-6M9 10l-2 8 5-3 5 3-2-8"/></svg>',
      NeckTies: '<svg viewBox="0 0 24 24"><path d="M10 3h4l1 3-3 2-3-2 1-3Zm2 5 2 12-2 2-2-2 2-12Z"/></svg>',
      Shirt: '<svg viewBox="0 0 24 24"><path d="m8 4 4 2 4-2 4 3-2 4-2-1v10H8V10l-2 1-2-4 4-3Z"/></svg>',
      Vest: '<svg viewBox="0 0 24 24"><path d="m8 3 4 3 4-3 3 3-2 15H7L5 6l3-3ZM12 6v12"/></svg>',
      Coat: '<svg viewBox="0 0 24 24"><path d="m8 3 4 3 4-3 3 4-2 14H7L5 7l3-4ZM12 6v15"/></svg>',
      CoatClosed: '<svg viewBox="0 0 24 24"><path d="m8 3 4 3 4-3 3 4-2 14H7L5 7l3-4ZM12 6v15"/></svg>',
      Poncho: '<svg viewBox="0 0 24 24"><path d="m12 3 8 16H4L12 3ZM12 8v7"/></svg>',
      Cloak: '<svg viewBox="0 0 24 24"><path d="M6 3h12l3 18H3L6 3ZM12 3v18"/></svg>',
      Dress: '<svg viewBox="0 0 24 24"><path d="m9 3 3 3 3-3 2 6-3 12H7L4 9l5-6Z"/></svg>',
      Pant: '<svg viewBox="0 0 24 24"><path d="M7 3h10l-1 18h-3l-1-9-1 9H8L7 3Z"/></svg>',
      Skirt: '<svg viewBox="0 0 24 24"><path d="M8 4h8l3 16H5L8 4ZM7 9h10"/></svg>',
      Chap: '<svg viewBox="0 0 24 24"><path d="M6 3h12v18h-4l-2-7-2 7H6V3Z"/></svg>',
      Boots: '<svg viewBox="0 0 24 24"><path d="M8 3v11l-4 3v3h8v-3l-1-3V3M16 3v11l-1 3v3h5v-3l-4-3"/></svg>',
      Spurs: '<svg viewBox="0 0 24 24"><path d="M4 14h16v4H4zM12 10v4M10 6l2 4 2-4"/></svg>',
      Spats: '<svg viewBox="0 0 24 24"><path d="M6 5h12v14H6zM10 5v14M14 5v14"/></svg>',
      Belt: '<svg viewBox="0 0 24 24"><path d="M3 9h18v6H3zM10 9v6h4V9"/></svg>',
      Gunbelt: '<svg viewBox="0 0 24 24"><path d="M3 10h18v5H3zM10 10v5h4v-5M6 15v4M18 15v4"/></svg>',
      Holster: '<svg viewBox="0 0 24 24"><path d="M7 4h10v7l-2 8H9l-2-8V4ZM9 7h6M10 19v2M14 19v2"/></svg>',
      Suspender: '<svg viewBox="0 0 24 24"><path d="m7 3 4 18M17 3l-4 18M7 3h10"/></svg>',
      Glove: '<svg viewBox="0 0 24 24"><path d="M8 4v7M11 3v8M14 4v7M17 6v7c0 5-3 8-6 8s-5-2-5-6v-4c0-1 2-1 2 0"/></svg>',
      Gauntlets: '<svg viewBox="0 0 24 24"><path d="M6 4h12l-2 16H8L6 4ZM10 4v16M14 4v16"/></svg>',
      Accessories: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="7"/><path d="M12 5v14M5 12h14"/></svg>',
      Bracelet: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="5"/></svg>',
      RingLh: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="6"/><path d="M12 2v4"/></svg>',
      RingRh: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="6"/><path d="M12 2v4"/></svg>',
      Satchels: '<svg viewBox="0 0 24 24"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="m4 10 8 4 8-4M12 14v6"/></svg>'
    };

    // Determine active group and available categories
    let currentGroup = WARDROBE_GROUPS.find(g => g.id === activeWardrobeGroup) || WARDROBE_GROUPS[0];
    const getGroupAvailableCats = (grp) => grp.cats.filter(cat => {
      if (activeGender === 'Male' && (cat === 'Skirt' || cat === 'Dress')) return false;
      return wardrobe[cat] && wardrobe[cat].length > 0;
    });

    let availableCatsInGroup = getGroupAvailableCats(currentGroup);
    if (availableCatsInGroup.length === 0) {
      for (const grp of WARDROBE_GROUPS) {
        const available = getGroupAvailableCats(grp);
        if (available.length > 0) {
          currentGroup = grp;
          activeWardrobeGroup = grp.id;
          availableCatsInGroup = available;
          break;
        }
      }
    }

    if (!availableCatsInGroup.includes(activeClothingCategory)) {
      activeClothingCategory = availableCatsInGroup[0] || 'Shirt';
    }

    // 1. Group navigation buttons
    let groupNavHtml = '<div class="wardrobe-group-nav">';
    WARDROBE_GROUPS.forEach(grp => {
      const isAct = grp.id === currentGroup.id;
      groupNavHtml += `<button class="wardrobe-group-btn ${isAct ? 'active' : ''}" data-group="${grp.id}">${grp.label}</button>`;
    });
    groupNavHtml += '</div>';

    // 2. Category pill buttons
    let pillTabsHtml = '';
    availableCatsInGroup.forEach(cat => {
      const isAct = cat === activeClothingCategory;
      const icon = CATEGORY_ICONS[cat] || '';
      pillTabsHtml += `
        <button class="clothing-pill ${isAct ? 'active' : ''}" data-cat="${cat}">
          ${icon}
          <span>${CATEGORY_NAMES[cat] || cat}</span>
        </button>
      `;
    });

    // 3. Raw items list (filtered to prevent duplicate "Без элемента")
    const rawList = (wardrobe[activeClothingCategory] || []).filter(it => it.hash && it.hash !== -1 && it.hash !== 0);
    const currentEquippedHash = Number(creatorState.comps[activeClothingCategory]);
    const hasNothingEquipped = !currentEquippedHash || currentEquippedHash === -1;

    let itemsHtml = `
      <div class="item-card ${hasNothingEquipped ? 'active' : ''}" data-cat="${activeClothingCategory}" data-comp="-1">
        <span class="item-card-title">Без элемента</span>
      </div>
    `;

    let activeModelItem = null;
    rawList.forEach((item, idx) => {
      const tints = item.tints || [item.hash];
      const isAct = (currentEquippedHash === Number(item.hash)) || (tints.some(t => Number(t) === currentEquippedHash));
      if (isAct) activeModelItem = item;
      itemsHtml += `
        <div class="item-card ${isAct ? 'active' : ''}" data-cat="${activeClothingCategory}" data-comp="${item.hash}" data-model-id="${item.id || idx}">
          <span class="item-card-title">${item.name || `Модель ${idx + 1}`}</span>
        </div>
      `;
    });

    // 4. Color / Variations Selector for currently active model
    let tintsHtml = '';
    if (activeModelItem && activeModelItem.tints && activeModelItem.tints.length > 1) {
      const tints = activeModelItem.tints;
      tintsHtml = `
        <div class="clothing-tints-panel">
          <div class="clothing-tints-header">Расцветка модели (${tints.length} вариаций)</div>
          <div class="clothing-tints-grid">
      `;
      tints.forEach((tHash, tIdx) => {
        const isTintAct = (currentEquippedHash === Number(tHash)) || (!currentEquippedHash && tIdx === 0);
        tintsHtml += `
          <button class="clothing-tint-chip ${isTintAct ? 'active' : ''}" data-cat="${activeClothingCategory}" data-tint-hash="${tHash}">
            Вариант ${tIdx + 1}
          </button>
        `;
      });
      tintsHtml += `
          </div>
        </div>
      `;
    }

    creatorTabContent.innerHTML = `
      <div class="creator-section">
        <span class="section-title">Гардероб и экипировка</span>
        ${groupNavHtml}
        <div class="clothing-pill-tabs">${pillTabsHtml}</div>
      </div>
      <div class="creator-section" style="margin-top:8px;">
        <span class="section-title">${CATEGORY_NAMES[activeClothingCategory] || activeClothingCategory}</span>
        <div class="items-grid" id="clothingGrid">${itemsHtml}</div>
        ${tintsHtml}
      </div>
    `;

    // Restore scroll positions if requested
    if (preserveScroll) {
      if (creatorTabContent) creatorTabContent.scrollTop = prevTabScroll;
      const newGrid = document.getElementById('clothingGrid');
      if (newGrid) newGrid.scrollTop = prevGridScroll;
    }

    // Group Tab Clicks
    document.querySelectorAll('.wardrobe-group-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        activeWardrobeGroup = e.currentTarget.dataset.group;
        const grp = WARDROBE_GROUPS.find(g => g.id === activeWardrobeGroup);
        const avail = grp ? getGroupAvailableCats(grp) : [];
        if (avail.length > 0) activeClothingCategory = avail[0];
        renderTabClothing(false);
      });
    });

    // Pill Tab Clicks
    document.querySelectorAll('.clothing-pill').forEach(pill => {
      pill.addEventListener('click', (e) => {
        activeClothingCategory = e.currentTarget.dataset.cat;
        renderTabClothing(false);
      });
    });

    // Clothing Item Card Clicks
    document.querySelectorAll('#clothingGrid .item-card').forEach(card => {
      card.addEventListener('click', (e) => {
        const cat = e.currentTarget.dataset.cat;
        const hash = parseInt(e.currentTarget.dataset.comp);

        creatorState.comps[cat] = hash;

        fetch(`https://${GetParentResourceName()}/creator:setClothing`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ category: cat, hash: hash })
        });

        renderTabClothing(true);
      });
    });

    // Clothing Tint Chip Clicks
    document.querySelectorAll('.clothing-tint-chip').forEach(chip => {
      chip.addEventListener('click', (e) => {
        const cat = e.currentTarget.dataset.cat;
        const hash = parseInt(e.currentTarget.dataset.tintHash);

        document.querySelectorAll('.clothing-tint-chip').forEach(c => c.classList.remove('active'));
        e.currentTarget.classList.add('active');

        creatorState.comps[cat] = hash;

        fetch(`https://${GetParentResourceName()}/creator:setClothing`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ category: cat, hash: hash })
        });
      });
    });
  }

  // =================================================================
  // Tab 7: Identity & Information (Single FullName, Age, Nation & Finish Button)
  // =================================================================
  function renderTabInfo() {
    if (pedCustom) {
      creatorTabContent.innerHTML = '<p>Внешность будет передана в библиотеку педов. Имя пресета задаётся там.</p><button id="finishPedCustom" class="hunt-btn">Готово — в библиотеку педов</button>';
      document.getElementById('finishPedCustom').onclick = () => {
        fetch(`https://${GetParentResourceName()}/creator:submitCharacter`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(creatorState)
        }).catch(() => showToast('Не удалось передать внешность', 'error'));
      };
      return;
    }
    const worldYear = Number(configData.worldYear) || 1907;
    const minAge = Number(configData.minAge) || 13;
    const maxAge = Number(configData.maxAge) || 80;
    // The server's historical character window is fixed to 1827–1894.  Keep
    // this explicit instead of deriving it from a potentially changed age
    // configuration, so the input and server always enforce the same range.
    const minBirthYear = 1827;
    const maxBirthYear = 1894;

    const formatAgeText = (age) => {
      const abs = Math.abs(Number(age));
      const mod10 = abs % 10;
      const mod100 = abs % 100;
      if (mod100 >= 11 && mod100 <= 19) return `${age} лет`;
      if (mod10 === 1) return `${age} год`;
      if (mod10 >= 2 && mod10 <= 4) return `${age} года`;
      return `${age} лет`;
    };

    const daysInMonth = (month, year) => {
      if (month === 2) return (year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0)) ? 29 : 28;
      return [4, 6, 9, 11].includes(month) ? 30 : 31;
    };

    const isValidBirthdate = (value) => {
      const match = String(value || '').match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
      if (!match) return false;
      const day = Number(match[1]), month = Number(match[2]), year = Number(match[3]);
      return year >= minBirthYear && year <= maxBirthYear
        && month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth(month, year);
    };

    const normaliseBirthdate = (raw) => {
      const digits = String(raw || '').replace(/\D/g, '').slice(0, 8);
      let day = digits.slice(0, 2);
      let month = digits.slice(2, 4);
      let year = digits.slice(4, 8);

      if (day.length > 0 && !/^[0-3]$/.test(day[0])) day = '';
      if (day.length === 2 && (Number(day) < 1 || Number(day) > 31)) day = day.slice(0, 1);

      if (month.length > 0 && !/^[01]$/.test(month[0])) month = '';
      if (month.length === 2 && (Number(month) < 1 || Number(month) > 12)) month = month.slice(0, 1);

      // Only prefixes of 1827–1894 are accepted while typing.  Incomplete
      // prefixes remain editable, but impossible digits are not kept.
      if (year.length > 0 && year[0] !== '1') year = '';
      if (year.length > 1 && year[1] !== '8') year = year.slice(0, 1);
      if (year.length > 2 && !/[2-9]/.test(year[2])) year = year.slice(0, 2);
      if (year.length === 4) {
        const number = Number(year);
        if (number < minBirthYear || number > maxBirthYear) year = year.slice(0, 3);
      }

      let formatted = day;
      if (digits.length > 2) formatted += `/${month}`;
      if (digits.length > 4) formatted += `/${year}`;
      return formatted;
    };

    let nationsOptionsHtml = '';
    const selectedNation = nationForGender(creatorState.nation, activeGender);
    creatorState.nation = selectedNation;
    NATIONS_LIST.forEach(n => {
      const displayNation = nationForGender(n, activeGender);
      const isSel = (selectedNation === displayNation);
      nationsOptionsHtml += `<option value="${displayNation}" ${isSel ? 'selected' : ''}>${displayNation}</option>`;
    });

    creatorTabContent.innerHTML = `
      <div class="info-hint-box">
        Имя и фамилия должны состоять максимум из двух слов, написанных <strong><u>на русском языке</u></strong> через пробел.
      </div>

      <div class="creator-section">
        <span class="section-title">Имя и Фамилия</span>
        <input type="text" id="inputFullName" class="hunt-input" placeholder="Джонс Джонсон" value="${creatorState.fullname || ''}" autocomplete="off" spellcheck="false">
        <p id="nameValidationHint" class="cam-hint" style="display: none;"></p>
      </div>

      <div class="creator-section">
        <span class="section-title">Дата рождения</span>
        <input type="text" inputmode="numeric" id="inputBirthdate" class="hunt-input" placeholder="ДД/ММ/ГГГГ" value="${creatorState.birthdate || ''}" maxlength="10" autocomplete="off">
        <span class="slider-label" id="birthdateAgeHint"></span>
      </div>

      <div class="creator-section">
        <span class="section-title">Национальность / Происхождение</span>
        <select id="selectNation" class="select-nation">
          ${nationsOptionsHtml}
        </select>
      </div>

      <div class="creator-submit-box">
        <button id="btnFinishCreator" class="btn-primary btn-submit-char" disabled>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 13l4 4L19 7"/></svg>
          Создать персонажа
        </button>
      </div>
    `;

    const inputFullName = document.getElementById('inputFullName');
    inputFullName.maxLength = 41;
    inputFullName.placeholder = 'Джонс Джонсон';
    const infoHint = creatorTabContent.querySelector('.info-hint-box');
    if (infoHint) {
      infoHint.innerHTML = 'Имя и фамилия должны состоять максимум из двух слов, написанных <strong><u>на русском языке</u></strong> через пробел.';
    }
    const nameValidationHint = document.getElementById('nameValidationHint');
    const inputBirthdate = document.getElementById('inputBirthdate');
    const birthdateAgeHint = document.getElementById('birthdateAgeHint');
    const selectNation = document.getElementById('selectNation');
    const btnFinish = document.getElementById('btnFinishCreator');

    function checkValidation() {
      const rawName = (inputFullName.value || '').trim();
      const parts = rawName.split(/\s+/);
      const hasBirthdate = isValidBirthdate(inputBirthdate.value);
      const isNameValid = (parts.length === 2 && /^[А-Яа-яЁё\-]+$/.test(parts[0]) && /^[А-Яа-яЁё\-]+$/.test(parts[1]) && parts[0].length >= 2 && parts[1].length >= 2 && hasBirthdate);

      if (isNameValid) {
        nameValidationHint.style.display = 'none';
        btnFinish.disabled = false;
        btnFinish.classList.add('ready');
      } else {
        nameValidationHint.style.display = 'none';
        btnFinish.disabled = true;
        btnFinish.classList.remove('ready');
      }
    }

    inputFullName.addEventListener('keydown', (e) => {
      if (e.key !== ' ') return;
      const before = inputFullName.value.slice(0, inputFullName.selectionStart).trim();
      if (before.split(/\s+/).filter(Boolean).length >= 2) e.preventDefault();
    });

    inputFullName.addEventListener('input', (e) => {
      const value = normaliseFullName(e.target.value);
      if (value !== e.target.value) e.target.value = value;
      creatorState.fullname = value;
      const words = value.trim().split(' ').filter(Boolean);
      creatorState.firstname = words[0] || '';
      creatorState.lastname = words[1] || '';
      checkValidation();
    });

    const updateBirthdate = () => {
      const value = normaliseBirthdate(inputBirthdate.value);
      inputBirthdate.value = value;
      creatorState.birthdate = value;
      const match = value.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
      if (!match || !isValidBirthdate(value)) {
        birthdateAgeHint.textContent = `Допустимый год: ${minBirthYear}–${maxBirthYear} (${formatAgeText(minAge)} - ${formatAgeText(maxAge)})`;
        checkValidation();
        return;
      }
      const age = worldYear - Number(match[3]);
      creatorState.age = age;
      birthdateAgeHint.textContent = `Возраст в ${worldYear}: ${formatAgeText(age)}`;
      checkValidation();
    };
    inputBirthdate.addEventListener('input', updateBirthdate);
    updateBirthdate();

    selectNation.addEventListener('change', (e) => {
      creatorState.nation = e.target.value;
      checkValidation();
    });

    btnFinish.addEventListener('click', () => {
      if (!btnFinish.disabled) {
        submitCharacter();
      }
    });

    checkValidation();
  }

  // =================================================================
  // Submit & Validation
  // =================================================================
  function submitCharacter() {
    if (isSubmitting) return;
    const rawName = (creatorState.fullname || '').trim();
    const parts = rawName.split(/\s+/);
    const hint = document.getElementById('nameValidationHint');

    if (parts.length !== 2) {
      if (hint) {
        hint.style.color = '#ef4444';
        hint.textContent = '⚠ Введите ИМЯ и ФАМИЛИЮ через один пробел (ровно 2 слова)';
      }
      return;
    }

    const fn = parts[0];
    const ln = parts[1];

    if (!/^[А-Яа-яЁё\-]+$/.test(fn) || !/^[А-Яа-яЁё\-]+$/.test(ln)) {
      if (hint) {
        hint.style.color = '#ef4444';
        hint.textContent = '⚠ Имя и фамилия должны содержать только русские буквы';
      }
      return;
    }

    const btnFinish = document.getElementById('btnFinishCreator');
    if (btnFinish) {
      btnFinish.disabled = true;
      isSubmitting = true;
      btnFinish.textContent = 'Создание персонажа...';
    }

    creatorState.firstname = capitaliseNameWord(fn);
    creatorState.lastname = capitaliseNameWord(ln);
    creatorState.age = parseInt(creatorState.age) || 25;
    creatorState.nation = creatorState.nation || 'Американец';

    fetch(`https://${GetParentResourceName()}/creator:submitCharacter`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(creatorState)
    }).catch(() => submissionFailed('Не удалось отправить данные персонажа. Попробуйте ещё раз.'));
  }

  return { init, open, close, submissionFailed };
})();
