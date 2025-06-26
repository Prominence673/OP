console.log("Script carrito.js cargado correctamente");

document.addEventListener("DOMContentLoaded", function() {
  const botones = document.querySelectorAll(".add-to-cart");

  // Toast personalizado
  function showToast(msg, color = "#004aad") {
    const toast = document.getElementById("toast-msg");
    if (!toast) return;
    toast.textContent = msg;
    toast.style.background = color;
    toast.classList.add("show");
    setTimeout(() => {
      toast.classList.remove("show");
    }, 2500);
  }

  botones.forEach((boton) => {
    boton.addEventListener("click", async (e) => {
      e.preventDefault(); // Evita el submit o navegación
      const id_paquete = boton.getAttribute("data-id_paquete");

      try {
        const response = await fetch("/op/BACK/PHP/agregar_item_carrito.php", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json"
          },
          body: JSON.stringify({
            id_paquete: parseInt(id_paquete),
            cantidad: 1
          })
        });

        const data = await response.json();

        if (data.error) {
          showToast(`Error: ${data.error}`, "#dc3545");
        } else {
          showToast("¡Producto agregado al carrito!", "#28a745");
        }
      } catch (error) {
        showToast("Error al comunicarse con el servidor.", "#dc3545");
      }
    });
  });
});