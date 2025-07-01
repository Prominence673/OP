const API_URL = "../../BACK/PHP/admin_tablas_api.php";
const REGISTROS_POR_PAGINA = 6;
const MAX_BOTONES = 10;

let datosTablaActual = [];
let paginaActual = 1;
let totalPaginas = 1;
let tablaActual = "";

// Cargar el selector de tablas dinámicamente
async function cargarSelectorTablas() {
  const section = document.querySelector(".section.is-main-section");
  const selectorDiv = document.createElement("div");
  selectorDiv.style = "margin-bottom:1em;display:flex;gap:1em;align-items:center;";
  selectorDiv.innerHTML = `
    <label for="tabla-select"><b>Ver tabla:</b></label>
    <select id="tabla-select" style="max-width:250px;"></select>
  `;
  section.insertBefore(selectorDiv, section.firstChild);

  // Obtener tablas reales
  const res = await fetch(API_URL);
  const tablas = await res.json();
  const select = document.getElementById("tabla-select");
  tablas.forEach(t => {
    const opt = document.createElement("option");
    opt.value = t;
    opt.textContent = t;
    select.appendChild(opt);
  });
  select.addEventListener("change", () => {
    paginaActual = 1;
    cargarTabla(select.value);
  });
  cargarTabla(select.value);
}

// Renderizar la tabla seleccionada con paginación
async function cargarTabla(nombre) {
  tablaActual = nombre;
  const card = document.querySelector(".card.has-table");
  if (!card) return;
  const cardContent = card.querySelector(".card-content");
  if (!cardContent) return;

  // Cambia el título de la tabla
  const cardHeaderTitle = card.querySelector(".card-header-title");
  if (cardHeaderTitle) {
    cardHeaderTitle.innerHTML = `<span class="icon"><i class="mdi mdi-table"></i></span> ${capitalizeFirstLetter(nombre)}`;
  }

  // Limpiar contenido
  cardContent.innerHTML = "";

  // Obtener datos
  const res = await fetch(`${API_URL}?tabla=${encodeURIComponent(nombre)}`);
  const data = await res.json();
  datosTablaActual = Array.isArray(data) ? data : [];
  totalPaginas = Math.ceil(datosTablaActual.length / REGISTROS_POR_PAGINA);
  renderTablaBD(nombre, paginaActual);
}

// Renderiza la tabla y la paginación
function renderTablaBD(nombre, pagina) {
  const card = document.querySelector(".card.has-table");
  if (!card) return;
  const cardContent = card.querySelector(".card-content");
  if (!cardContent) return;

  if (!Array.isArray(datosTablaActual) || datosTablaActual.length === 0) {
    cardContent.innerHTML = `<div class="content has-text-grey has-text-centered"><p>No hay registros en <b>${nombre}</b></p></div>`;
    return;
  }

  // Paginación
  totalPaginas = Math.ceil(datosTablaActual.length / REGISTROS_POR_PAGINA);
  if (pagina < 1) pagina = 1;
  if (pagina > totalPaginas) pagina = totalPaginas;
  paginaActual = pagina;

  const inicio = (pagina - 1) * REGISTROS_POR_PAGINA;
  const fin = inicio + REGISTROS_POR_PAGINA;
  const datosPagina = datosTablaActual.slice(inicio, fin);

  // Cabeceras
  const headers = Object.keys(datosPagina[0]);
  let html = `<div class="table-wrapper has-mobile-cards" style="overflow-x:auto;max-width:100vw;"><table class="table is-fullwidth is-striped is-hoverable is-fullwidth" style="min-width:900px;"><thead><tr>`;
  headers.forEach(h => html += `<th>${h}</th>`);
  html += `</tr></thead><tbody>`;
  datosPagina.forEach(row => {
    html += "<tr>";
    headers.forEach(h => html += `<td>${row[h] ?? ""}</td>`);
    html += "</tr>";
  });
  html += "</tbody></table></div>";

  // Paginación avanzada
  html += `<div class="notification">
    <div class="level">
      <div class="level-left">
        <div class="level-item">
          <div class="buttons has-addons">`;

  // Siempre mostrar el botón 1
  if (paginaActual !== 1) {
    html += `<button type="button" class="button" data-pagina="1">1</button>`;
  } else {
    html += `<button type="button" class="button is-active" data-pagina="1">1</button>`;
  }

  // Calcular rango de botones intermedios
  let start = Math.max(2, paginaActual - Math.floor((MAX_BOTONES - 2) / 2));
  let end = start + MAX_BOTONES - 2;
  if (end >= totalPaginas) {
    end = totalPaginas - 1;
    start = Math.max(2, end - (MAX_BOTONES - 2));
  }

  // Si hay hueco entre 2 y start, muestra "..."
  if (start > 2) {
    html += `<span class="button is-static">...</span>`;
  }

  // Botones intermedios
  for (let i = start; i <= end && i < totalPaginas; i++) {
    if (i === paginaActual) {
      html += `<button type="button" class="button is-active" data-pagina="${i}">${i}</button>`;
    } else {
      html += `<button type="button" class="button" data-pagina="${i}">${i}</button>`;
    }
  }

  // Si hay hueco antes del último, muestra "..."
  if (end < totalPaginas - 1) {
    html += `<span class="button is-static">...</span>`;
  }

  // Botón último (solo si hay más de una página)
  if (totalPaginas > 1) {
    if (paginaActual === totalPaginas) {
      html += `<button type="button" class="button is-active" data-pagina="${totalPaginas}">${totalPaginas}</button>`;
    } else {
      html += `<button type="button" class="button" data-pagina="${totalPaginas}">${totalPaginas}</button>`;
    }
  }

  html += `</div>
        </div>
      </div>
      <div class="level-right">
        <div class="level-item">
          <small>Page ${paginaActual} of ${totalPaginas}</small>
        </div>
      </div>
    </div>
  </div>`;

  cardContent.innerHTML = html;

  // Asignar eventos a los botones de paginación
  cardContent.querySelectorAll("button[data-pagina]").forEach(btn => {
    btn.addEventListener("click", () => {
      renderTablaBD(tablaActual, parseInt(btn.dataset.pagina));
    });
  });

  // Botón recargar
  const recargarBtn = document.querySelector(".card-header-icon");
  if (recargarBtn) {
    recargarBtn.onclick = (e) => {
      e.preventDefault();
      cargarTabla(tablaActual);
    };
  }
}

// Utilidad para capitalizar el nombre de la tabla
function capitalizeFirstLetter(str) {
  if (!str) return "";
  return str.charAt(0).toUpperCase() + str.slice(1);
}

document.addEventListener("DOMContentLoaded", cargarSelectorTablas);