// =================================================================
// HUNT: Hard RP — UI Controls & Text Input Focus Guide Compliance
// =================================================================

(function() {
  function updateFocusState(hasFocus) {
    fetch(`https://${GetParentResourceName()}/setInputFocusState`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hasFocus: hasFocus })
    }).catch(() => {});
  }

  document.addEventListener('focusin', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
      updateFocusState(true);
    }
  });

  document.addEventListener('focusout', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
      updateFocusState(false);
    }
  });
})();
