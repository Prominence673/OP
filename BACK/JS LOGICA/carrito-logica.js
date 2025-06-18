document.addEventListener("DOMContentLoaded", function() {
    // Cargar items del carrito al abrir la página
    cargarCarrito();

    // Función para cargar los items del carrito
    async function cargarCarrito() {
        try {
            const response = await fetch("/op/BACK/PHP/obtener_carrito.php");
            
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
            
            // Guardar carrito en localStorage para el checkout
            localStorage.setItem('carritoCheckout', JSON.stringify(data.items));
            
        } catch (error) {
            console.error("Error:", error);
            mostrarError("No se pudo cargar el carrito. Intenta nuevamente.");
        }
    }

    // Función para mostrar los items en el carrito
    function mostrarItemsCarrito(items) {
        const listaCarrito = document.getElementById("lista-carrito");
        
        if (items.length === 0) {
            listaCarrito.innerHTML = '<div class="carrito-vacio">Tu carrito está vacío</div>';
            return;
        }
        
        listaCarrito.innerHTML = items.map(item => `
            <div class="item-carrito" data-id="${item.id}">
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

    // Función para calcular el total
    function calcularTotal(items) {
        const total = items.reduce((sum, item) => sum + (item.precio * item.cantidad), 0);
        document.getElementById("total-carrito").textContent = `$${total.toLocaleString()}`;
        
        // Guardar el total en localStorage para usarlo en el checkout
        localStorage.setItem('totalCarrito', total);
    }

    // Función para mostrar errores
    function mostrarError(mensaje) {
        const listaCarrito = document.getElementById("lista-carrito");
        listaCarrito.innerHTML = `<div class="error-carrito">${mensaje}</div>`;
    }

    // Función para agregar event listeners a los botones
    function agregarEventListeners() {
        // Botones de cantidad (+/-)
        document.querySelectorAll(".btn-cantidad").forEach(btn => {
            btn.addEventListener("click", async function() {
                const itemElement = this.closest(".item-carrito");
                const itemId = itemElement.dataset.id;
                const esSumar = this.classList.contains("sumar");
                
                // Animación de click
                this.style.transform = "scale(0.9)";
                setTimeout(() => { this.style.transform = "scale(1)"; }, 100);
                
                try {
                    const response = await fetch("/op/BACK/PHP/actualizar_cantidad.php", {
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
                    
                    // Actualizar visualmente la cantidad antes de recargar
                    const cantidadElement = itemElement.querySelector(".cantidad-valor");
                    const cantidadActual = parseInt(cantidadElement.textContent);
                    cantidadElement.textContent = esSumar ? cantidadActual + 1 : Math.max(1, cantidadActual - 1);
                    
                    // Recalcular el subtotal y total
                    const precio = parseFloat(itemElement.querySelector(".info-item p").textContent.replace(/[^0-9.-]+/g,""));
                    const nuevaCantidad = parseInt(cantidadElement.textContent);
                    itemElement.querySelector(".subtotal-item").textContent = `$${(precio * nuevaCantidad).toLocaleString()}`;
                    cargarCarrito(); // Esto recargará el total general
                    
                } catch (error) {
                    console.error("Error:", error);
                    alert("Error al actualizar: " + error.message);
                }
            });
        });
        
        // Botones de eliminar
        document.querySelectorAll(".eliminar-item").forEach(btn => {
            btn.addEventListener("click", async function() {
                if (!confirm("¿Seguro quieres eliminar este artículo?")) return;
                
                const itemElement = this.closest(".item-carrito");
                const itemId = itemElement.dataset.id;
                
                // Animación de eliminación
                itemElement.classList.add("eliminando");
                await new Promise(resolve => setTimeout(resolve, 300));
                
                try {
                    const response = await fetch("/op/BACK/PHP/eliminar_item.php", {
                        method: "POST",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ item_id: itemId })
                    });
                    
                    if (!response.ok) throw new Error("Error al eliminar");
                    
                    cargarCarrito();
                    
                } catch (error) {
                    console.error("Error:", error);
                    itemElement.classList.remove("eliminando");
                    alert("Error al eliminar: " + error.message);
                }
            });
        });
        
        // Botón de finalizar compra - Versión profesional
        document.getElementById("finalizar-compra")?.addEventListener("click", async function() {
            const btn = this;
            btn.innerHTML = '<span class="spinner">⌛</span> Procesando...';
            btn.disabled = true;
            
            try {
                // Obtener el carrito actualizado
                await cargarCarrito();
                
                // Redirigir a la página de checkout
                window.location.href = "/op/FRONT/HTML/checkout.html";
                
            } catch (error) {
                console.error("Error al finalizar compra:", error);
                btn.innerHTML = 'Finalizar Compra';
                btn.disabled = false;
                alert('Ocurrió un error: ' + error.message);
            }
        });
    }
});