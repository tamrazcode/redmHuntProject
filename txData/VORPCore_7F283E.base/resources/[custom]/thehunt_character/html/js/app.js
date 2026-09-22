// =================================================================
// HUNT: Hard RP — NUI Main Message Dispatcher & App Initialization
// =================================================================

document.addEventListener('DOMContentLoaded', () => {
  SelectionUI.init();
  CreatorUI.init();

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'openSelection') {
      CreatorUI.close();
      SelectionUI.open(data);
    } else if (data.action === 'closeSelection') {
      SelectionUI.close();
    } else if (data.action === 'openCreator') {
      SelectionUI.close();
      CreatorUI.open(data);
    } else if (data.action === 'closeCreator') {
      CreatorUI.close();
    } else if (data.action === 'showNotification') {
      showToast(data.message, data.type || 'info');
    } else if (data.action === 'creatorSubmissionFailed') {
      CreatorUI.submissionFailed(data.message);
      showToast(data.message, 'error');
    } else if (data.action === 'selectionActionFailed') {
      SelectionUI.actionFailed();
    }
  });
});

function showToast(message, type) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `hunt-toast ${type}`;
  toast.textContent = message;

  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    toast.style.transition = 'all 0.3s ease';
    setTimeout(() => {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 300);
  }, 4000);
}
