window.addEventListener('scroll', function () {
  const nosotros = document.querySelector('.section-nosotros');
  if (nosotros) {
    let offset = window.pageYOffset;
    nosotros.style.backgroundPositionY = `${offset * 0.5}px`;
  }
});

// Parallax suave solo para la sección Nosotros
window.addEventListener('scroll', () => {
  const section = document.querySelector('.section-nosotros');
  if (!section) return;

  const scrollY = window.scrollY;
  const offsetTop = section.offsetTop;
  const height = section.offsetHeight;

  if (scrollY + window.innerHeight > offsetTop && scrollY < offsetTop + height) {
    const relativeY = scrollY - offsetTop;
    const movement = Math.min(Math.max(relativeY * 0.2, -50), 50); // Limita el movimiento entre -50 y 50px
    section.style.backgroundPosition = `center ${50 + movement}px`;
  }
});

