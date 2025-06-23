document.addEventListener("DOMContentLoaded", function() {
  const elements = document.querySelectorAll('.slide-in');

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      } else {
        entry.target.classList.remove('visible');
      }
    });
  }, { threshold: 0.2 });

  elements.forEach(el => observer.observe(el));
});