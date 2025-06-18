document.addEventListener("DOMContentLoaded", function () {
  const userMenuBtn = document.getElementById("user-menu-btn");
  const dropdown = document.querySelector(".dropdown");

  userMenuBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    dropdown.classList.toggle("show");
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest(".user-menu")) {
      dropdown.classList.remove("show");
    }
  });
});