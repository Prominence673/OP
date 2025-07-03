document.addEventListener("DOMContentLoaded", () => {
const API_CRUD = "../../BACK/PHP/tabla_crud.php";
let selectedRowId = null;

// Cierra todos los formularios de acción
function cerrarTodosLosFormularios() {
  document.getElementById('form-hard-delete').style.display = 'none';
  document.getElementById('form-soft-delete').style.display = 'none';
  document.getElementById('form-add').style.display = 'none';
  document.getElementById('form-edit').style.display = 'none';
}

// Selección de fila (agrega highlight y guarda ID)
document.body.addEventListener("click", function(e) {
  const tr = e.target.closest("tr");
  if (tr && tr.parentElement.tagName === "TBODY") {
    document.querySelectorAll("tbody tr").forEach(row => row.classList.remove("is-selected"));
    tr.classList.add("is-selected");
    selectedRowId = tr.firstElementChild ? tr.firstElementChild.textContent : null;
  }
});

// Obtiene campos de la tabla y genera inputs
async function generarInputsFormulario(tabla, formId, values = {}) {
  const res = await fetch(API_CRUD, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tabla, accion: "campos" })
  });
  const campos = await res.json();
  const form = document.querySelector(`#${formId} form`);

  // Detecta la clave primaria (primer campo que empieza con id_)
  const primaryKey = campos.find(c => c.startsWith("id_"));

  // Limpia campos previos (menos el título y botones)
  form.querySelectorAll(".field").forEach(f => {
  if (!f.classList.contains("is-grouped")) f.remove(); // solo elimina los campos, NO los botones
    });
  campos.forEach(campo => {
  if (campo === "id_activo" || (formId === "form-add" && campo === primaryKey)) return;
  let value = values[campo] ?? "";
  const inputField = document.createRange().createContextualFragment(`
    <div class="field">
      <label class="label">${campo}</label>
      <div class="control">
        <input class="input" name="${campo}" type="text" value="${value}">
      </div>
    </div>
  `);
  const beforeNode = form.querySelector(".field.is-grouped") || null;
  if (beforeNode) {
    form.insertBefore(inputField, beforeNode);
  } else {
    form.appendChild(inputField);
  }
});

  // Habilita el botón de acción siempre que haya al menos un campo
const btn = form.querySelector(".confirm-action");

if (btn) {
  btn.disabled = form.querySelectorAll("input[name]").length === 0;
  form.querySelectorAll("input[name]").forEach(inp => {
    inp.oninput = () => {
      let algunoConValor = Array.from(form.querySelectorAll("input[name]")).some(i => i.value.trim() !== "");
      btn.disabled = !algunoConValor;
    };
  });
} else {
  console.warn("No se encontró el botón de acción dentro del formulario:", formId);
}
   
}

// Mostrar y activar el formulario correspondiente al hacer click en cada botón
document.getElementById('btn-hard-delete-row').onclick = function() {
  cerrarTodosLosFormularios();
  document.getElementById('form-hard-delete').style.display = 'block';
};
document.getElementById('btn-soft-delete-row').onclick = function() {
  cerrarTodosLosFormularios();
  document.getElementById('form-soft-delete').style.display = 'block';
};
document.getElementById('btn-add-row').onclick = async function() {
  cerrarTodosLosFormularios();
  await generarInputsFormulario(window.tablaActual, "form-add");
  document.getElementById('form-add').style.display = 'block';
  document.querySelectorAll('#form-add input, #form-add button').forEach(el => el.disabled = false);
};
document.getElementById('btn-edit-row').onclick = async function() {
  if (!selectedRowId) return alert("Selecciona una fila para modificar.");
  cerrarTodosLosFormularios();
  // Trae datos actuales
  const res = await fetch(API_CRUD, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tabla: window.tablaActual, accion: "get", id: selectedRowId })
  });
  const values = await res.json();
  await generarInputsFormulario(window.tablaActual, "form-edit", values);
  document.getElementById('form-edit').style.display = 'block';
  document.querySelectorAll('#form-edit input, #form-edit button').forEach(el => el.disabled = false);
};

// También cierra el formulario al hacer click en "Cancelar"
document.querySelectorAll('#form-hard-delete .button.is-light, #form-soft-delete .button.is-light, #form-add .button.is-light, #form-edit .button.is-light').forEach(btn => {
  btn.onclick = function() {
    cerrarTodosLosFormularios();
  };
});

// --- ACCIONES CRUD ---

// Añadir
document.getElementById('confirm-add').onclick = async function() {
  const form = document.querySelector("#form-add form");
  const data = {};
  form.querySelectorAll("input[name]").forEach(inp => data[inp.name] = inp.value);
  const res = await fetch(API_CRUD, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tabla: window.tablaActual, accion: "add", data })
  });
  const r = await res.json();
  alert(r.ok ? "Registro añadido" : (r.error || "Error"));
  cerrarTodosLosFormularios();
  if (window.cargarTabla) window.cargarTabla(window.tablaActual);
};

// Modificar
document.getElementById('confirm-edit').onclick = async function() {
  if (!selectedRowId) return alert("Selecciona una fila para modificar.");
  const form = document.querySelector("#form-edit form");
  const data = {};
  form.querySelectorAll("input[name]").forEach(inp => data[inp.name] = inp.value);
  const res = await fetch(API_CRUD, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tabla: window.tablaActual, accion: "edit", id: selectedRowId, data })
  });
  const r = await res.json();
  alert(r.ok ? "Registro modificado" : (r.error || "Error"));
  cerrarTodosLosFormularios();
  if (window.cargarTabla) window.cargarTabla(window.tablaActual);
};

// Soft delete
document.getElementById('confirm-soft-delete').onclick = async function() {
  if (!selectedRowId) return alert("Selecciona una fila para eliminar (soft).");
  const res = await fetch(API_CRUD, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tabla: window.tablaActual, accion: "soft_delete", id: selectedRowId })
  });
  const r = await res.json();
  alert(r.ok ? "Registro desactivado" : (r.error || "Error"));
  cerrarTodosLosFormularios();
  if (window.cargarTabla) window.cargarTabla(window.tablaActual);
};

// Hard delete
document.getElementById('confirm-hard-delete').onclick = async function() {
  if (!selectedRowId) return alert("Selecciona una fila para eliminar (hard).");
  const res = await fetch(API_CRUD, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tabla: window.tablaActual, accion: "hard_delete", id: selectedRowId })
  });
  const r = await res.json();
  alert(r.ok ? "Registro eliminado" : (r.error || "Error"));
  cerrarTodosLosFormularios();
  if (window.cargarTabla) window.cargarTabla(window.tablaActual);
};
});