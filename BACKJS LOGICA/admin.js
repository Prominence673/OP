
document.addEventListener("DOMContentLoaded", () => {

  const camposPorTabla = {
    autos: `
      <label>Nombre: <input name="nombre" required></label>
      <label>Tipo: <input name="tipo" required></label>
      <label>Capacidad: <input name="capacidad" type="number" required></label>
      <label>Precio: <input name="precio" type="number" required></label>
      <label>Imagen (URL o nombre): <input name="imagen" required></label>
      <label>Imagen Interior (URL o nombre): <input name="imagen_interior"></label>
    `,
    pasajes: `
      <label>Nombre: <input name="nombre" required></label>
      <label>Imagen (URL o nombre): <input name="imagen" required></label>
      <label>Aerolínea: <input name="aerolinea" required></label>
      <label>Duración: <input name="duracion" required></label>
      <label>Precio desde: <input name="precio_desde" type="number" required></label>
      <label>Clase: <input name="clase" required></label>
    `,
    paquetes: `
      <label>Nombre del viaje: <input name="nombre_viaje" required></label>
      <label>Imagen (URL o nombre): <input name="imagen" required></label>
      <label>Duración: <input name="duracion" required></label>
      <label>Incluye: <input name="incluye" required></label>
      <label>Precio aprox: <input name="precio_aprox" type="number" required></label>
    `,
    estadias: `
      <label>Nombre: <input name="nombre" required></label>
      <label>Imagen (URL o nombre): <input name="imagen" required></label>
      <label>Ubicación: <input name="ubicacion" required></label>
      <label>Descripción: <input name="descripcion" required></label>
      <label>Precio: <input name="precio" type="number" required></label>
    `
  };
  const selectTabla = document.getElementById("tabla-insertar");
  const camposDiv = document.getElementById("campos-insertar");
  function mostrarCampos() {
    camposDiv.innerHTML = camposPorTabla[selectTabla.value];
  }
  selectTabla.addEventListener("change", mostrarCampos);
  mostrarCampos();


  const camposPorTablaUsuario = {
    usuarios: `
      <label>Mail: <input name="mail" required></label>
      <label>Contraseña: <input name="contrasena" type="password" required></label>
      <label>Rol: <input name="rol" required></label>
    `,
    opiniones: `
      <label>ID Usuario: <input name="id_usuario" required></label>
      <label>Mensaje: <input name="mensaje" required></label>
      <label>Fecha: <input name="fecha" type="date" required></label>
    `,
    detalle_pedido: `
      <label>ID Pedido: <input name="id_pedido" required></label>
      <label>Nombre Producto: <input name="nombre_producto" required></label>
      <label>Precio: <input name="precio" type="number" required></label>
      <label>Cantidad: <input name="cantidad" type="number" required></label>
    `,
    datos_personales: `
      <label>ID Usuario: <input name="id_usuario" required></label>
      <label>Nombre: <input name="nombre" required></label>
      <label>Apellido: <input name="apellido" required></label>
      <label>DNI: <input name="dni" required></label>
      <label>Teléfono: <input name="telefono" required></label>
      <label>Dirección: <input name="direccion" required></label>
      <label>ID Localidad: <input name="id_localidad" required></label>
    `,
    localidad: `
      <label>Nombre: <input name="nombre" required></label>
      <label>ID Partido: <input name="id_partido" required></label>
    `,
    provincia: `
      <label>Nombre: <input name="nombre" required></label>
    `,
    partido: `
      <label>Nombre: <input name="nombre" required></label>
      <label>ID Provincia: <input name="id_provincia" required></label>
    `
  };
  const selectInsertarUsuario = document.getElementById("tabla-insertar-usuario");
  const camposInsertarDiv = document.getElementById("campos-insertar-usuario");
  const selectModificarUsuario = document.getElementById("tabla-modificar-usuario");
  const camposModificarDiv = document.getElementById("campos-modificar-usuario");
  function mostrarCamposUsuario(select, div) {
    div.innerHTML = camposPorTablaUsuario[select.value] || "";
  }
  selectInsertarUsuario.addEventListener("change", () => mostrarCamposUsuario(selectInsertarUsuario, camposInsertarDiv));
  mostrarCamposUsuario(selectInsertarUsuario, camposInsertarDiv);
  selectModificarUsuario.addEventListener("change", () => mostrarCamposUsuario(selectModificarUsuario, camposModificarDiv));
  mostrarCamposUsuario(selectModificarUsuario, camposModificarDiv);


  const eliminarPor = document.getElementById("eliminar-por");
  const campoEliminar = document.getElementById("campo-eliminar");
  function mostrarCampoEliminar() {
    if (eliminarPor.value === "id") {
      campoEliminar.innerHTML = '<label>ID: <input name="id" type="number" required></label>';
    } else {
      campoEliminar.innerHTML = '<label>Nombre: <input name="nombre" required></label>';
    }
  }
  eliminarPor.addEventListener("change", mostrarCampoEliminar);
  mostrarCampoEliminar();

 
  const campoEliminarUsuario = document.getElementById("campo-eliminar-usuario");
  document.getElementById("eliminar-usuario-por").addEventListener("change", e => {
    campoEliminarUsuario.innerHTML = e.target.value === "id"
      ? '<label>ID: <input name="id" type="number" required></label>'
      : '<label>Nombre: <input name="nombre" required></label>';
  });

  // ========== NAVEGACIÓN ENTRE SECCIONES ==========

  document.querySelectorAll('.admin-nav a[data-section="productos"]').forEach(link => {
    link.addEventListener('click', function(e) {
      e.preventDefault();
      document.querySelectorAll('.contenido-seccion').forEach(sec => sec.hidden = true);
      const productosSection = document.getElementById('productos');
      if (productosSection) productosSection.hidden = false;
      document.querySelectorAll('#productos .contenido-subseccion').forEach(sub => sub.hidden = true);
      const verProductos = document.getElementById('ver-productos');
      if (verProductos) verProductos.hidden = false;
    });
  });

  document.querySelectorAll('.admin-nav a[data-section="usuarios"]').forEach(link => {
    link.addEventListener('click', function(e) {
      e.preventDefault();
      document.querySelectorAll('.contenido-seccion').forEach(sec => sec.hidden = true);
      const usuariosSection = document.getElementById('usuarios');
      if (usuariosSection) usuariosSection.hidden = false;
      document.querySelectorAll('#usuarios .contenido-subseccion').forEach(sub => sub.hidden = true);
      const verUsuarios = document.getElementById('ver-usuarios');
      if (verUsuarios) verUsuarios.hidden = false;
    });
  });

  // ========== TABLA DE PRODUCTOS ==========
  const selectProducto = document.getElementById("tipo-producto");
  const tablaProductosContainer = document.getElementById("tabla-productos-container");
  function renderTable(tipo, data) {
    if (!Array.isArray(data) || data.length === 0) {
      tablaProductosContainer.innerHTML = "<p>No hay datos para mostrar.</p>";
      return;
    }
    let headers = [];
    switch (tipo) {
      case "coches":
        headers = ["ID", "Nombre", "Imagen", "Tipo", "Capacidad", "Precio", "Imagen Interior", "Acciones"];
        break;
      case "paquetes":
        headers = ["ID", "Nombre del viaje", "Imagen", "Duración", "Incluye", "Precio aprox", "Acciones"];
        break;
      case "estadias":
        headers = ["ID", "Nombre", "Imagen", "Ubicación", "Descripción", "Precio", "Acciones"];
        break;
      case "pasajes":
        headers = ["ID", "Nombre", "Imagen", "Aerolínea", "Duración", "Precio desde", "Clase", "Acciones"];
        break;
    }
    let html = "<table class='tabla-productos'><thead><tr>";
    headers.forEach(h => html += `<th>${h}</th>`);
    html += "</tr></thead><tbody>";
    data.forEach(row => {
      html += "<tr>";
      switch (tipo) {
        case "coches":
          html += `<td>${row.id_autos}</td>
                   <td>${row.nombre}</td>
                   <td><img src="${row.imagen}" alt="" style="max-width:80px;max-height:50px;"></td>
                   <td>${row.tipo}</td>
                   <td>${row.capacidad}</td>
                   <td>$${row.precio}</td>
                   <td><img src="${row.imagen_interior}" alt="" style="max-width:80px;max-height:50px;"></td>`;
          break;
        case "paquetes":
          html += `<td>${row.id_paquetes}</td>
                   <td>${row.nombre_viaje}</td>
                   <td><img src="${row.imagen}" alt="" style="max-width:80px;max-height:50px;"></td>
                   <td>${row.duracion}</td>
                   <td>${row.incluye}</td>
                   <td>$${row.precio_aprox}</td>`;
          break;
        case "estadias":
          html += `<td>${row.id_estadias}</td>
                   <td>${row.nombre}</td>
                   <td><img src="${row.imagen}" alt="" style="max-width:80px;max-height:50px;"></td>
                   <td>${row.ubicacion}</td>
                   <td>${row.descripcion}</td>
                   <td>$${row.precio}</td>`;
          break;
        case "pasajes":
          html += `<td>${row.id_pasajes}</td>
                   <td>${row.nombre}</td>
                   <td><img src="${row.imagen}" alt="" style="max-width:80px;max-height:50px;"></td>
                   <td>${row.aerolinea}</td>
                   <td>${row.duracion}</td>
                   <td>$${row.precio_desde}</td>
                   <td>${row.clase}</td>`;
          break;
      }
      html += `<td>
        <button class="btn-accion btn-eliminar" title="Eliminar" data-id="${row.id_autos || row.id_paquetes || row.id_estadias || row.id_pasajes}" data-tipo="${tipo}" onclick="abrirEliminarProducto('${tipo}', '${row.id_autos || row.id_paquetes || row.id_estadias || row.id_pasajes}')">🗑️</button>
        <button class="btn-accion btn-modificar" title="Modificar" data-id="${row.id_autos || row.id_paquetes || row.id_estadias || row.id_pasajes}" data-tipo="${tipo}" onclick="abrirModificarProducto('${tipo}', '${row.id_autos || row.id_paquetes || row.id_estadias || row.id_pasajes}')">✏️</button>
        <button class="btn-accion btn-agregar" title="Añadir" data-tipo="${tipo}" onclick="abrirAgregarProducto('${tipo}')">＋</button>
      </td>`;
      html += "</tr>";
    });
    html += "</tbody></table>";
    tablaProductosContainer.innerHTML = html;
  }
  function cargarProductos(tipo) {
    fetch("../../BACK/PHP/productos_api.php?tipo=" + tipo)
      .then(res => res.json())
      .then(data => renderTable(tipo, data))
      .catch(() => {
        tablaProductosContainer.innerHTML = "<p>Error al cargar los productos.</p>";
      });
  }
  selectProducto.addEventListener("change", () => {
    cargarProductos(selectProducto.value);
  });
  cargarProductos(selectProducto.value);

  // ========== TABLA DE USUARIOS ==========
  let usuariosData = [];
  let usuariosPaginaActual = 1;
  const usuariosPorPagina = 8;
  const selectTablaVer = document.getElementById("tipo-usuario-ver");
  function renderUsuariosPaginados(tabla, dataOverride) {
    const tablaResultados = document.getElementById("tabla-usuarios-resultados");
    const data = dataOverride || usuariosData;
    if (!Array.isArray(data) || data.length === 0) {
      tablaResultados.innerHTML = "<p>No hay datos para mostrar.</p>";
      return;
    }
    const headers = Object.keys(data[0]);
    const inicio = (usuariosPaginaActual - 1) * usuariosPorPagina;
    const paginados = data.slice(inicio, inicio + usuariosPorPagina);
    let html = "<table class='tabla-productos'><thead><tr>";
    headers.forEach(h => html += `<th>${h}</th>`);
    html += "<th>Acciones</th></tr></thead><tbody>";
    paginados.forEach(row => {
      html += "<tr>";
      headers.forEach(h => html += `<td>${row[h]}</td>`);
      const id = row.id_usuario || row.id_dato || row.id_tarjeta || row.id_pedido || row.id_provincia || row.id_partido || row.id_localidad || row.id_detallepedido || row.id_opinion || row.id_rol;
      html += `<td>
        <button class='btn-accion btn-eliminar' data-id="${id}" data-tipo="${tabla}" onclick="abrirEliminarUsuario('${tabla}', ${id})">🗑️</button>
        <button class='btn-accion btn-modificar' data-id="${id}" data-tipo="${tabla}" onclick="abrirModificarUsuario('${tabla}', ${id})">✏️</button>
        <button class='btn-accion btn-agregar' data-tipo="${tabla}" onclick="abrirAgregarUsuario('${tabla}')">＋</button>
      </td>`;
      html += "</tr>";
    });
    html += "</tbody></table>";
    html += `<div class='paginacion'>
      <button onclick='cambiarPaginaUsuarios(-1)' ${usuariosPaginaActual === 1 ? "disabled" : ""}>⬅️ Anterior</button>
      <span>Página ${usuariosPaginaActual} de ${Math.ceil(usuariosData.length / usuariosPorPagina)}</span>
      <button onclick='cambiarPaginaUsuarios(1)' ${usuariosPaginaActual >= Math.ceil(usuariosData.length / usuariosPorPagina) ? "disabled" : ""}>Siguiente ➡️</button>
    </div>`;
    tablaResultados.innerHTML = html;
  }
  window.cambiarPaginaUsuarios = function(cambio) {
    usuariosPaginaActual += cambio;
    renderUsuariosPaginados(document.getElementById("tipo-usuario-ver").value);
  };
  function cargarTablaUsuarios(tabla) {
    fetch(`../../BACK/PHP/admin_tablas_api.php?tabla=${tabla}`)
      .then(r => r.json())
      .then(data => {
        usuariosData = data;
        usuariosPaginaActual = 1;
        renderUsuariosPaginados(tabla);
      })
      .catch(() => {
        document.getElementById("tabla-usuarios-resultados").innerHTML = "<p>Error al cargar los datos.</p>";
      });
  }
  selectTablaVer.addEventListener("change", () => cargarTablaUsuarios(selectTablaVer.value));
  cargarTablaUsuarios(selectTablaVer.value);
});

// ========== FUNCIONES PARA ACCIONES ==========
function abrirEliminarProducto(tabla, id) {
  document.querySelectorAll('.contenido-seccion').forEach(sec => sec.hidden = true);
  document.getElementById('eliminar-producto').hidden = false;
  document.querySelector('#eliminar-producto select[name="tabla"]').value = tabla === "coches" ? "autos" : tabla;
  document.getElementById('eliminar-por').value = "id";
  document.getElementById('campo-eliminar').innerHTML = `<label>ID: <input name="id" type="number" value="${id}" required></label>`;
}
function abrirModificarProducto(tabla, id) {
  document.querySelectorAll('.contenido-seccion').forEach(sec => sec.hidden = true);
  document.getElementById('modificar-producto').hidden = false;
  document.querySelector('#modificar-producto select[name="tabla"]').value = tabla === "coches" ? "autos" : tabla;
  document.querySelector('#modificar-producto input[name="id"]').value = id;
}
function abrirAgregarProducto(tabla) {
  document.querySelectorAll('.contenido-seccion').forEach(sec => sec.hidden = true);
  document.getElementById('agregar-producto').hidden = false;
  document.getElementById('tabla-insertar').value = tabla === "coches" ? "autos" : tabla;
  document.getElementById('tabla-insertar').dispatchEvent(new Event('change'));
}
function abrirEliminarUsuario(tabla, id) {
  document.querySelectorAll('.contenido-subseccion').forEach(sec => sec.hidden = true);
  document.getElementById('eliminar-usuario').hidden = false;
  document.querySelector('#eliminar-usuario select[name="tabla"]').value = tabla;
  document.getElementById('eliminar-usuario-por').value = "id";
  document.getElementById('campo-eliminar-usuario').innerHTML = `<label>ID: <input name="id" type="number" value="${id}" required></label>`;
}
function abrirModificarUsuario(tabla, id) {
  document.querySelectorAll('.contenido-subseccion').forEach(sec => sec.hidden = true);
  document.getElementById('modificar-usuario').hidden = false;
  document.querySelector('#tabla-modificar-usuario').value = tabla;
  document.querySelector('#form-modificar-usuario input[name="id"]').value = id;
  document.getElementById('tabla-modificar-usuario').dispatchEvent(new Event('change'));
}
function abrirAgregarUsuario(tabla) {
  document.querySelectorAll('.contenido-subseccion').forEach(sec => sec.hidden = true);
  document.getElementById('agregar-usuario').hidden = false;
  document.querySelector('#tabla-insertar-usuario').value = tabla;
  document.getElementById('tabla-insertar-usuario').dispatchEvent(new Event('change'));
}

