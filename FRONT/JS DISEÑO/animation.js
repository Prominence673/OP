document.addEventListener("DOMContentLoaded", function() {
  const cards = document.querySelectorAll('.opcion-card');
  const observer = new IntersectionObserver((entries, obs) => {
    entries.forEach((entry, idx) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.classList.add('visible');
        }, idx * 180); // Efecto uno por uno
        obs.unobserve(entry.target);
      }
    });
  }, { threshold: 0.3 });

  cards.forEach(card => observer.observe(card));
});