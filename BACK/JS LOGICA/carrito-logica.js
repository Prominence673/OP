document.addEventListener("DOMContentLoaded", function() {

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

    cargarCarrito();


    async function cargarCarrito() {
        try {
            const response = await fetch("../../BACK/PHP/obtener_carrito.php");
            
            if (!response.ok) {
                throw new Error("Error al cargar el carrito");
            }
            const data = await response.json();
       
            if (data.error) {
                mostrarError(data.error);
                return;
            }
            
            mostrarItemsCarrito(data.items);
            calcularTotal(data.items);
        
            localStorage.setItem('carritoCheckout', JSON.stringify(data.items));
            
        } catch (error) {
            console.error("Error:", error);
            mostrarError("No se pudo cargar el carrito. Intenta nuevamente.");
        }
    }

    
    function mostrarItemsCarrito(items) {
        const listaCarrito = document.getElementById("lista-carrito");
        
        if (items.length === 0) {
            listaCarrito.innerHTML = '<div class="carrito-vacio">Tu carrito está vacío</div>';
            return;
        }
        
        listaCarrito.innerHTML = items.map(item => `
            <div class="item-carrito" data-id="${item.id_item}">
                <div class="info-item">
                    <h3>${item.nombre}</h3>
                    <p>Precio unitario: $${item.precio.toLocaleString()}</p>
                </div>
                <div class="cantidad-item">
                    <button class="btn-cantidad restar">-</button>
                    <span class="cantidad-valor">${item.cantidad}</span>
                    <button class="btn-cantidad sumar">+</button>
                </div>
                <div class="subtotal-item">
                    $${(item.precio * item.cantidad).toLocaleString()}
                </div>
                <button class="eliminar-item">✕ Eliminar</button>
            </div>
        `).join("");
        
        agregarEventListeners();
    }


    function calcularTotal(items) {
        const total = items.reduce((sum, item) => sum + (item.precio * item.cantidad), 0);
        document.getElementById("total-carrito").textContent = `$${total.toLocaleString()}`;
        
     
        localStorage.setItem('totalCarrito', total);
    }


    function mostrarError(mensaje) {
        const listaCarrito = document.getElementById("lista-carrito");
        listaCarrito.innerHTML = `<div class="error-carrito">${mensaje}</div>`;
    }


    function agregarEventListeners() {
  
        document.querySelectorAll(".btn-cantidad").forEach(btn => {
            btn.addEventListener("click", async function() {
                const itemElement = this.closest(".item-carrito");
                const itemId = itemElement.dataset.id;
                const esSumar = this.classList.contains("sumar");

                this.style.transform = "scale(0.9)";
                setTimeout(() => { this.style.transform = "scale(1)"; }, 100);

                try {
                    const response = await fetch("../../BACK/PHP/actualizar_cantidad.php", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({
                            item_id: itemId,
                            operacion: esSumar ? "sumar" : "restar"
                        })
                    });

                    if (!response.ok) throw new Error("Error en la actualización");

                    const result = await response.json();
                    if (result.error) throw new Error(result.error);

                    const cantidadElement = itemElement.querySelector(".cantidad-valor");
                    const cantidadActual = parseInt(cantidadElement.textContent);
                    cantidadElement.textContent = esSumar ? cantidadActual + 1 : Math.max(1, cantidadActual - 1);

                    const precio = parseFloat(itemElement.querySelector(".info-item p").textContent.replace(/[^0-9.-]+/g,""));
                    const nuevaCantidad = parseInt(cantidadElement.textContent);
                    itemElement.querySelector(".subtotal-item").textContent = `$${(precio * nuevaCantidad).toLocaleString()}`;
                    cargarCarrito();

                    showToast("Cantidad actualizada", "#28a745");

                } catch (error) {
                    console.error("Error:", error);
                    showToast("Error al actualizar: " + error.message, "#dc3545");
                }
            });
        });
        

        document.querySelectorAll(".eliminar-item").forEach(btn => {
            btn.addEventListener("click", async function() {                
                const itemElement = this.closest(".item-carrito");
                const itemId = itemElement.dataset.id;

                itemElement.classList.add("eliminando");
                await new Promise(resolve => setTimeout(resolve, 300));
                
                try {
                    const response = await fetch("../../BACK/PHP/eliminar_item.php", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ item_id: itemId })
                    });
                    
                    if (!response.ok) throw new Error("Error al eliminar");
                    
                    cargarCarrito();
                    showToast("Producto eliminado del carrito", "#dc3545");

                } catch (error) {
                    console.error("Error:", error);
                    itemElement.classList.remove("eliminando");
                    showToast("Error al eliminar: " + error.message, "#dc3545");
                }
            });
        });
        

        document.getElementById("finalizar-compra")?.addEventListener("click", async function() {
            const btn = this;
            btn.innerHTML = '<span class="spinner">⌛</span> Procesando...';
            btn.disabled = true;
            
            try {
                await cargarCarrito();
                window.location.href = "../../FRONT/HTML/finalizar_compra.html";
            } catch (error) {
                console.error("Error al finalizar compra:", error);
                btn.innerHTML = 'Finalizar Compra';
                btn.disabled = false;
                showToast('Ocurrió un error: ' + error.message, "#dc3545");
            }
        });
    }
});