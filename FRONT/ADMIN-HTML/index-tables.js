const API_URL = "../../BACK/PHP/admin_tablas_api.php";
const REGISTROS_POR_PAGINA = 6;
const MAX_BOTONES = 10;

// Agrega "detalle_pedido" a las tablas compatibles
const TABLAS_COMPATIBLES = ["usuarios", "pedido", "opiniones", "detalle_pedido"];

let datosTablaActual = [];
let paginaActual = 1;
let totalPaginas = 1;
let tablaActual = "";

// Estadísticas por tabla (ajustado para pedido y detalle_pedido)
function getEstadisticas(tabla, datos) {
  switch (tabla) {
    case "usuarios":
      return {
        card1: { label: "Usuarios", value: datos.length, icon: "mdi-account-multiple", color: "primary" },
        card2: { label: "Emails únicos", value: new Set(datos.map(u => u.mail)).size, icon: "mdi-email", color: "info" },
        card3: { label: "Activos", value: datos.filter(u => u.activo == 1).length, icon: "mdi-check-circle", color: "success" }
      };
    case "pedido":
      return {
        card1: { label: "Pedidos", value: datos.length, icon: "mdi-cart-outline", color: "primary" },
        card2: { label: "Total ventas", value: "$" + datos.reduce((a, p) => a + (parseFloat(p.total) || 0), 0).toLocaleString(), icon: "mdi-cash", color: "info" },
        card3: { label: "Último pedido", value: datos.length ? (datos[datos.length-1].fecha || "-") : "-", icon: "mdi-calendar", color: "success" }
      };
    case "detalle_pedido":
      return {
        card1: { label: "Detalles", value: datos.length, icon: "mdi-format-list-bulleted", color: "primary" },
        card2: { label: "Pedidos únicos", value: new Set(datos.map(d => d.id_pedido)).size, icon: "mdi-cart", color: "info" },
        card3: { label: "Último detalle", value: datos.length ? (datos[datos.length-1].id_detalle_pedido || "-") : "-", icon: "mdi-numeric", color: "success" }
      };
    case "opiniones":
      return {
        card1: { label: "Opiniones", value: datos.length, icon: "mdi-comment-multiple", color: "primary" },
        card2: { label: "Con teléfono", value: datos.filter(o => o.telefono && o.telefono.length > 0).length, icon: "mdi-phone", color: "info" },
        card3: { label: "Última", value: datos.length ? (datos[datos.length-1].fecha || "-") : "-", icon: "mdi-calendar", color: "success" }
      };
    default:
      return {
        card1: { label: "Registros", value: datos.length, icon: "mdi-database", color: "primary" },
        card2: { label: "Columnas", value: datos[0] ? Object.keys(datos[0]).length : 0, icon: "mdi-table-column", color: "info" },
        card3: { label: "Último ID", value: datos.length ? (datos[datos.length-1].id || "-") : "-", icon: "mdi-numeric", color: "success" }
      };
  }
}

// Renderiza las tarjetas de estadísticas
function renderEstadisticas(tabla, datos) {
  const cards = getEstadisticas(tabla, datos);
  const tile = document.querySelector(".tile.is-ancestor");
  if (!tile) return;
  tile.innerHTML = `
    <div class="tile is-parent">
      <div class="card tile is-child">
        <div class="card-content">
          <div class="level is-mobile">
            <div class="level-item">
              <div class="is-widget-label"><h3 class="subtitle is-spaced">
                ${cards.card1.label}
              </h3>
                <h1 class="title">
                  ${cards.card1.value}
                </h1>
              </div>
            </div>
            <div class="level-item has-widget-icon">
              <div class="is-widget-icon"><span class="icon has-text-${cards.card1.color} is-large"><i
                  class="mdi ${cards.card1.icon} mdi-48px"></i></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="tile is-parent">
      <div class="card tile is-child">
        <div class="card-content">
          <div class="level is-mobile">
            <div class="level-item">
              <div class="is-widget-label"><h3 class="subtitle is-spaced">
                ${cards.card2.label}
              </h3>
                <h1 class="title">
                  ${cards.card2.value}
                </h1>
              </div>
            </div>
            <div class="level-item has-widget-icon">
              <div class="is-widget-icon"><span class="icon has-text-${cards.card2.color} is-large"><i
                  class="mdi ${cards.card2.icon} mdi-48px"></i></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="tile is-parent">
      <div class="card tile is-child">
        <div class="card-content">
          <div class="level is-mobile">
            <div class="level-item">
              <div class="is-widget-label"><h3 class="subtitle is-spaced">
                ${cards.card3.label}
              </h3>
                <h1 class="title">
                  ${cards.card3.value}
                </h1>
              </div>
            </div>
            <div class="level-item has-widget-icon">
              <div class="is-widget-icon"><span class="icon has-text-${cards.card3.color} is-large"><i
                  class="mdi ${cards.card3.icon} mdi-48px"></i></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

// Gráfico dinámico (sin "pendiente" en pedido)
function renderGrafico(tabla, datos) {
  const ctx = document.getElementById("big-line-chart").getContext("2d");
  if (window.bigChart) window.bigChart.destroy();

  let chartType = "line";
  let chartData = { labels: [], datasets: [] };

  // Utilidad para obtener el campo de fecha correcto según la tabla
  function getFecha(row) {
    if (tabla === "usuarios") return (row.fecha_alta || row.fecha || row.created_at || "");
    if (tabla === "pedido") return (row.fecha || row.fecha_pedido || row.created_at || "");
    if (tabla === "detalle_pedido") return (row.fecha || row.fecha_detalle || row.created_at || "");
    if (tabla === "opiniones") return (row.fecha || row.created_at || "");
    return "";
  }

  // Fecha actual en formato YYYY-MM-DD
  const hoy = new Date();
  const hoyStr = hoy.toISOString().slice(0, 10);

  function esFechaValida(fecha) {
    if (!fecha || typeof fecha !== "string" || fecha.length < 7) return false;
    return fecha.slice(0, 10) <= hoyStr;
  }

  if (tabla === "usuarios") {
    // Línea por mes
    const porMes = {};
    datos.forEach(u => {
      const fecha = getFecha(u);
      if (esFechaValida(fecha)) {
        const mes = fecha.slice(0, 7);
        porMes[mes] = (porMes[mes] || 0) + 1;
      }
    });
    chartData.labels = Object.keys(porMes);
    chartData.datasets = [{
      label: "Usuarios nuevos",
      data: Object.values(porMes),
      borderColor: "#0077cc",
      backgroundColor: "rgba(0,119,204,0.1)",
      fill: true
    }];
    chartType = "line";
    // Si no hay fechas válidas, mostrar torta activos/inactivos
    if (chartData.labels.length === 0 && datos.length > 0) {
      const activos = datos.filter(u => u.activo == 1).length;
      const inactivos = datos.length - activos;
      chartData = {
        labels: ["Activos", "Inactivos"],
        datasets: [{
          data: [activos, inactivos],
          backgroundColor: ["#50C9CE", "#FF6600"]
        }]
      };
      chartType = "pie";
    }
  } else if (tabla === "pedido") {
    // Línea por mes
    const porMes = {};
    datos.forEach(p => {
      const fecha = getFecha(p);
      if (esFechaValida(fecha)) {
        const mes = fecha.slice(0, 7);
        porMes[mes] = (porMes[mes] || 0) + (parseFloat(p.total) || 0);
      }
    });
    chartData.labels = Object.keys(porMes);
    chartData.datasets = [{
      label: "Ventas ($)",
      data: Object.values(porMes),
      borderColor: "#50C9CE",
      backgroundColor: "rgba(80,201,206,0.1)",
      fill: true
    }];
    chartType = "line";
    // Si no hay fechas válidas, mostrar barras por estado
    if (chartData.labels.length === 0 && datos.length > 0 && datos[0].estado) {
      const porEstado = {};
      datos.forEach(p => {
        const estado = p.estado || "Otro";
        porEstado[estado] = (porEstado[estado] || 0) + 1;
      });
      chartData = {
        labels: Object.keys(porEstado),
        datasets: [{
          label: "Pedidos por estado",
          data: Object.values(porEstado),
          backgroundColor: "#50C9CE"
        }]
      };
      chartType = "bar";
    }
  } else if (tabla === "detalle_pedido") {
    // Línea por mes si hay fecha, si no, barras por producto
    const tieneFecha = datos.some(d => esFechaValida(getFecha(d)));
    if (tieneFecha) {
      const porMes = {};
      datos.forEach(d => {
        const fecha = getFecha(d);
        if (esFechaValida(fecha)) {
          const mes = fecha.slice(0, 7);
          porMes[mes] = (porMes[mes] || 0) + 1;
        }
      });
      chartData.labels = Object.keys(porMes);
      chartData.datasets = [{
        label: "Detalles de pedido",
        data: Object.values(porMes),
        borderColor: "#ffb347",
        backgroundColor: "rgba(255,179,71,0.1)",
        fill: true
      }];
      chartType = "line";
    } else {
      // Barras por producto
      const porProducto = {};
      datos.forEach(d => {
        const prod = d.id_producto || d.producto || "Otro";
        porProducto[prod] = (porProducto[prod] || 0) + 1;
      });
      chartData = {
        labels: Object.keys(porProducto),
        datasets: [{
          label: "Cantidad por producto",
          data: Object.values(porProducto),
          backgroundColor: "#ffb347"
        }]
      };
      chartType = "bar";
    }
  } else if (tabla === "opiniones") {
    // Línea por mes
    const porMes = {};
    datos.forEach(o => {
      const fecha = getFecha(o);
      if (esFechaValida(fecha)) {
        const mes = fecha.slice(0, 7);
        porMes[mes] = (porMes[mes] || 0) + 1;
      }
    });
    chartData.labels = Object.keys(porMes);
    chartData.datasets = [{
      label: "Opiniones",
      data: Object.values(porMes),
      borderColor: "#FF6600",
      backgroundColor: "rgba(255,102,0,0.1)",
      fill: true
    }];
    chartType = "line";
    // Si no hay fechas válidas, mostrar barras por motivo
    if (chartData.labels.length === 0 && datos.length > 0 && datos[0].id_motivo) {
      const porMotivo = {};
      datos.forEach(o => {
        const motivo = o.id_motivo || "Otro";
        porMotivo[motivo] = (porMotivo[motivo] || 0) + 1;
      });
      chartData = {
        labels: Object.keys(porMotivo),
        datasets: [{
          label: "Opiniones por motivo",
          data: Object.values(porMotivo),
          backgroundColor: "#FF6600"
        }]
      };
      chartType = "bar";
    }
  } else {
    chartData.labels = [];
    chartData.datasets = [];
    chartType = "bar";
  }

  // Si no hay datos, muestra un gráfico vacío
  if (chartData.labels.length === 0) {
    chartData.labels = [""];
    chartData.datasets = [{
      label: "Sin datos",
      data: [0],
      borderColor: "#ccc",
      backgroundColor: "rgba(200,200,200,0.1)",
      fill: true
    }];
    chartType = "bar";
  }

  window.bigChart = new Chart(ctx, {
    type: chartType,
    data: chartData,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      legend: { display: true }
    }
  });
}

// Selector de tablas dinámico
async function cargarSelectorTablas() {
  const selectorDiv = document.getElementById("selector-tablas-container");
  selectorDiv.innerHTML = `
    <label for="tabla-select"><b>Ver tabla:</b></label>
    <select id="tabla-select" style="max-width:250px;"></select>
  `;
  // Obtener tablas reales
  const res = await fetch(API_URL);
  let tablas = await res.json();
  tablas = tablas.filter(t => TABLAS_COMPATIBLES.includes(t)); // Solo compatibles
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

// Renderizar la tabla seleccionada con paginación y estadísticas
async function cargarTabla(nombre) {
  tablaActual = nombre;
  const card = document.querySelector(".card.has-table");
  if (!card) return;
  const cardContent = card.querySelector(".card-content");
  if (!cardContent) return;

  // Cambia el título de la tabla
  const cardHeaderTitle = card.querySelector(".card-header-title");
  if (cardHeaderTitle) {
    cardHeaderTitle.innerHTML = `<span class="icon"><i class="mdi mdi-table"></i></span> <span id="tabla-titulo">${capitalizeFirstLetter(nombre)}</span>`;
  }

  // Limpiar contenido
  cardContent.innerHTML = "";

  // Obtener datos
  const res = await fetch(`${API_URL}?tabla=${encodeURIComponent(nombre)}`);
  const data = await res.json();
  datosTablaActual = Array.isArray(data) ? data : [];
  totalPaginas = Math.ceil(datosTablaActual.length / REGISTROS_POR_PAGINA);

  // Actualiza estadísticas y gráfico
  renderEstadisticas(nombre, datosTablaActual);
  renderGrafico(nombre, datosTablaActual);

  renderTablaBD(nombre, paginaActual);
}

// Renderiza la tabla y la paginación (igual que en tables.js)
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

  // Paginación avanzada (igual que en tables.js)
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
  const recargarBtn = document.getElementById("recargar-tabla");
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