console.log("Script carrito.js cargado correctamente");

document.addEventListener("DOMContentLoaded", function() {
  const botones = document.querySelectorAll(".add-to-cart");
  
  botones.forEach((boton) => {
    boton.addEventListener("click", async () => {
      const id_paquete = boton.getAttribute("data-id_paquete");
      console.log(`Agregando paquete ID: ${id_paquete}`);
      
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

        if (!response.ok) {
          throw new Error(`Error HTTP! estado: ${response.status}`);
        }

        const data = await response.json();
        console.log("Respuesta del servidor:", data);
        
        if (data.error) {
          alert(`Error: ${data.error}`);
        } else {
          alert(data.mensaje || "¡Producto agregado al carrito!");
        }
      } catch (error) {
        console.error("Error en la petición:", error);
        alert("Error al comunicarse con el servidor. Por favor, inténtalo de nuevo.");
      }
    });
  });
});