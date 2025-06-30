function showToast(message, type = "success") {
  const toast = document.getElementById("toast-msg");
  toast.textContent = message;
  toast.className = "show " + type;
  setTimeout(() => {
    toast.className = toast.className.replace("show", "");
  }, 3000);
}