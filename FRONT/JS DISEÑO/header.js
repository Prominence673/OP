document.addEventListener("DOMContentLoaded", function() {
  const header = document.querySelector('.site-header');
  function updateHeaderShape() {
    if (window.scrollY <= 2) {
      header.classList.add('header-rounded');
    } else {
      header.classList.remove('header-rounded');
    }
  }
  updateHeaderShape();
  window.addEventListener('scroll', updateHeaderShape);
  window.addEventListener('load', updateHeaderShape);
});