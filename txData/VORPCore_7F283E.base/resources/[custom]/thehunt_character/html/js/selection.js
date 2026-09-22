// =================================================================
// HUNT: Hard RP — Character Selection Controller
// Clean RP Card: Name, Age, Nationality Only
// =================================================================

const SelectionUI = (function() {
  let characters = [];
  let selectedIndex = 0;
  let maxSlots = 3;
  let isAdmin = false;
  let deleteTargetChar = null;
  let actionPending = false;

  const selectionScreen = document.getElementById('selectionScreen');
  const slotsGrid = document.getElementById('slotsGrid');
  const selectionFooter = document.getElementById('selectionFooter');
  const slotCapacity = document.getElementById('slotCapacity');
  const deleteModal = document.getElementById('deleteModal');
  const deleteCharName = document.getElementById('deleteCharName');
  const deleteConfirmInput = document.getElementById('deleteConfirmInput');
  const deleteErrorText = document.getElementById('deleteErrorText');
  const btnCancelDelete = document.getElementById('btnCancelDelete');
  const btnConfirmDelete = document.getElementById('btnConfirmDelete');

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, char => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    }[char]));
  }

  function init() {
    btnCancelDelete.addEventListener('click', closeDeleteModal);
    btnConfirmDelete.addEventListener('click', executeDelete);
    deleteConfirmInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') executeDelete();
      if (e.key === 'Escape') closeDeleteModal();
    });
  }

  function open(data) {
    characters = data.characters || [];
    maxSlots = data.maxSlots !== undefined ? data.maxSlots : 3;
    isAdmin = data.isAdmin || false;
    selectedIndex = 0;
    actionPending = false;
    if (btnConfirmDelete) btnConfirmDelete.disabled = false;

    if (slotCapacity) {
      const limit = maxSlots === -1 ? '∞' : maxSlots;
      slotCapacity.textContent = `Занято слотов: ${characters.length} / ${limit}`;
    }

    renderSlots();
    renderFooter();
    selectionScreen.classList.remove('hidden');
  }

  function close() {
    selectionScreen.classList.add('hidden');
    closeDeleteModal();
    actionPending = false;
  }

  function renderSlots() {
    slotsGrid.innerHTML = '';

    characters.forEach((char, idx) => {
      const card = document.createElement('div');
      card.className = `slot-card ${idx === selectedIndex ? 'active' : ''}`;
      card.dataset.index = idx;

      card.innerHTML = `
          <div class="slot-name">${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}</div>
        <div class="slot-stats-grid">
          <div class="stat-col">
            <span class="stat-label">Возраст</span>
            <span class="stat-value">${escapeHtml(char.age || 25)} лет</span>
          </div>
          <div class="stat-col">
            <span class="stat-label">Дата рождения</span>
            <span class="stat-value">${escapeHtml(char.birthdate || 'Не указана')}</span>
          </div>
          <div class="stat-col">
            <span class="stat-label">Национальность</span>
            <span class="stat-value">${escapeHtml(char.nation || 'Американец')}</span>
          </div>
        </div>
      `;

      card.addEventListener('click', () => {
        selectSlot(idx);
      });

      slotsGrid.appendChild(card);
    });

    // Check if player can create another character
    const canCreate = (maxSlots === -1) || (characters.length < maxSlots);
    if (canCreate) {
      const emptyCard = document.createElement('div');
      emptyCard.className = 'slot-card empty-slot';
      emptyCard.innerHTML = `
        <span class="empty-plus-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M12 5v14M5 12h14"/></svg></span>
        <div class="empty-slot-text">Создать нового персонажа</div>
      `;
      emptyCard.addEventListener('click', () => {
        if (actionPending) return;
        actionPending = true;
        fetch(`https://${GetParentResourceName()}/selection:create`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        });
      });
      slotsGrid.appendChild(emptyCard);
    }
  }

  function selectSlot(idx) {
    if (actionPending) return;
    selectedIndex = idx;
    const cards = slotsGrid.querySelectorAll('.slot-card');
    cards.forEach((c, i) => {
      if (i === idx) c.classList.add('active');
      else c.classList.remove('active');
    });

    renderFooter();

    fetch(`https://${GetParentResourceName()}/selection:selectSlot`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ index: idx + 1 })
    });
  }

  function renderFooter() {
    const selectedChar = characters[selectedIndex];
    if (!selectedChar) {
      selectionFooter.innerHTML = `<div style="text-align:center; font-size:11px; color:#8c909c;">Нет выбранного персонажа</div>`;
      return;
    }

    selectionFooter.innerHTML = `
      <div class="selection-actions-grid">
        <button id="btnDeleteChar" class="btn-danger">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2M10 11v6M14 11v6"/></svg>
          Удалить
        </button>
        <button id="btnPlayChar" class="btn-primary">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
          Войти в мир
        </button>
      </div>
    `;

    document.getElementById('btnPlayChar').addEventListener('click', () => {
      if (actionPending) return;
      actionPending = true;
      document.getElementById('btnPlayChar').disabled = true;
      fetch(`https://${GetParentResourceName()}/selection:play`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ charIdentifier: selectedChar.charIdentifier })
      });
    });

    document.getElementById('btnDeleteChar').addEventListener('click', () => {
      openDeleteModal(selectedChar);
    });
  }

  function openDeleteModal(char) {
    deleteTargetChar = char;
    deleteCharName.textContent = `${char.firstname} ${char.lastname}`;
    deleteConfirmInput.value = '';
    deleteErrorText.classList.add('hidden');
    deleteModal.classList.remove('hidden');
    deleteConfirmInput.focus();
  }

  function closeDeleteModal() {
    deleteModal.classList.add('hidden');
    deleteTargetChar = null;
  }

  // Used only for delete confirmation. The creator's live name formatting is
  // intentionally left unchanged.
  function normalizeDeleteName(value) {
    return String(value ?? '')
      .normalize('NFC')
      .replace(/[\u200B-\u200D\uFEFF]/g, '')
      .replace(/[\s\u00A0]+/g, ' ')
      .trim()
      .toLowerCase();
  }

  function executeDelete() {
    if (!deleteTargetChar || actionPending) return;

    const inputName = normalizeDeleteName(deleteConfirmInput.value);
    const expectedName = normalizeDeleteName(`${deleteTargetChar.firstname} ${deleteTargetChar.lastname}`);

    if (inputName !== expectedName) {
      deleteErrorText.classList.remove('hidden');
      deleteConfirmInput.focus();
      return;
    }

    actionPending = true;
    btnConfirmDelete.disabled = true;
    fetch(`https://${GetParentResourceName()}/selection:delete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        charIdentifier: deleteTargetChar.charIdentifier,
        confirmName: deleteConfirmInput.value.trim()
      })
    });

    closeDeleteModal();
  }

  function actionFailed() {
    actionPending = false;
    if (btnConfirmDelete) btnConfirmDelete.disabled = false;
    renderFooter();
  }

  return { init, open, close, actionFailed };
})();
