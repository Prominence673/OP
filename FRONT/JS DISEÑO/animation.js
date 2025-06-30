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

document.addEventListener("DOMContentLoaded", function() {
  const words = ["NOSOTROS", "KAPIFLY"];
  const el = document.getElementById("typewrite-dynamic");
  let wordIndex = 0;
  let charIndex = 0;
  let typing = true;

  function type() {
    const currentWord = words[wordIndex];
    if (typing) {
      if (charIndex < currentWord.length) {
        el.textContent += currentWord.charAt(charIndex);
        charIndex++;
        setTimeout(type, 90);
      } else {
        typing = false;
        setTimeout(type, 1200); // Espera antes de borrar
      }
    } else {
      if (charIndex > 0) {
        el.textContent = currentWord.substring(0, charIndex - 1);
        charIndex--;
        setTimeout(type, 50);
      } else {
        typing = true;
        wordIndex = (wordIndex + 1) % words.length;
        setTimeout(type, 400); // Espera antes de volver a escribir
      }
    }
  }
  el.textContent = "";
  type();
});