document.addEventListener("DOMContentLoaded", function () {
  const userIcon = document.querySelector(".user-icon");
  const dropdown = document.querySelector(".dropdown");

  userIcon.addEventListener("click", (e) => {
    e.stopPropagation(); // evita cierre inmediato por el listener global
    dropdown.classList.toggle("show");
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest(".user-menu")) {
      dropdown.classList.remove("show");
    }
  });
});