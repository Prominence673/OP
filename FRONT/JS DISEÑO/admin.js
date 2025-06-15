document.addEventListener("DOMContentLoaded", () => {
  const sectionLinks = document.querySelectorAll("[data-section]");
  const subsectionLinks = document.querySelectorAll("[data-subsection]");
  const allSections = document.querySelectorAll(".contenido-seccion");

  const productosLink = document.querySelector('[data-section="productos"]');
  const submenu = document.querySelector(".submenu");
  const welcomeMessage = document.querySelector(".welcome-message");

  function mostrarSeccion(id) {
    // Ocultar todas las secciones
    allSections.forEach(sec => sec.hidden = true);

    // Mostrar la sección correspondiente
    const target = document.getElementById(id);
    if (target) target.hidden = false;

    // Quitar clases activas
    document.querySelectorAll(".admin-nav a").forEach(link => link.classList.remove("activo"));

    // Marcar enlace activo
    const activeLink = document.querySelector(`[data-section="${id}"], [data-subsection="${id}"]`);
    if (activeLink) activeLink.classList.add("activo");

    // Mostrar u ocultar el mensaje de bienvenida
    if (id === "inicio") {
      welcomeMessage.style.display = "block";
    } else {
      welcomeMessage.style.display = "none";
    }

    // Si se selecciona una subsección de productos, mantener el submenú abierto
    if (activeLink && activeLink.dataset.subsection) {
      submenu.style.display = "block";
      productosLink.classList.add("activo");
    } else if (id !== "productos") {
      submenu.style.display = "none";
    }
  }

  // Mostrar sección principal (Inicio, Usuarios, Configuración)
  sectionLinks.forEach(link => {
    const id = link.dataset.section;

    if (id === "productos") {
      link.addEventListener("click", e => {
        e.preventDefault();
        // Toggle del submenú
        submenu.style.display = submenu.style.display === "block" ? "none" : "block";
      });
    } else {
      link.addEventListener("click", e => {
        e.preventDefault();
        mostrarSeccion(id);
      });
    }
  });

  // Mostrar subsección de productos
  subsectionLinks.forEach(link => {
    link.addEventListener("click", e => {
      e.preventDefault();
      const id = link.dataset.subsection;
      mostrarSeccion(id);
    });
  });

  // Mostrar inicio por defecto
  mostrarSeccion("inicio");
});
