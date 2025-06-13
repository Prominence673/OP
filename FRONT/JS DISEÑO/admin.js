document.addEventListener("DOMContentLoaded", () => {
  const sectionLinks = document.querySelectorAll("[data-section]");
  const subsectionLinks = document.querySelectorAll("[data-subsection]");
  const allSections = document.querySelectorAll(".contenido-seccion");

  function mostrarSeccion(id) {
    allSections.forEach(sec => sec.hidden = true);
    const target = document.getElementById(id);
    if (target) target.hidden = false;
  }

  // Manejo de secciones principales (Inicio, Usuarios, Configuración)
  sectionLinks.forEach(link => {
    link.addEventListener("click", e => {
      e.preventDefault();
      const id = link.dataset.section;
      mostrarSeccion(id);
    });
  });

  // Manejo de subsecciones dentro de Productos
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
