function showToast(msg, color = "#004aad") {
  const toast = document.getElementById("toast-msg");
  if (!toast) return;
  toast.textContent = msg;
  toast.style.background = color;
  toast.classList.add("show");
  setTimeout(() => {
    toast.classList.remove("show");
  }, 2500);
}