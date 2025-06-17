document.addEventListener("DOMContentLoaded", function() {
    // Cargar datos del carrito
    const carrito = JSON.parse(localStorage.getItem("carritoCheckout")) || [];
    const total = parseFloat(localStorage.getItem("totalCarrito")) || 0;
    
    mostrarResumenCompra(carrito, total);
    actualizarTotalPago(total);
    
    // Inicializar opciones de cuotas
    actualizarOpcionesCuotas(total);

    // Manejar cambio de métodos de pago
    document.querySelectorAll(".payment-method").forEach(method => {
        method.addEventListener("click", function() {
            document.querySelectorAll(".payment-method").forEach(m => m.classList.remove("active"));
            this.classList.add("active");
            
            const method = this.dataset.method;
            
            if (method === "cash") {
                document.getElementById("payment-form").style.display = "none";
                document.getElementById("cash-message").style.display = "block";
                document.getElementById("installments-group").style.display = "none";
            } else {
                document.getElementById("payment-form").style.display = "block";
                document.getElementById("cash-message").style.display = "none";
                
                // Mostrar cuotas solo para crédito
                document.getElementById("installments-group").style.display = 
                    method === "credit" ? "block" : "none";
            }
        });
    });

    // Formatear número de tarjeta
    document.getElementById("card-number")?.addEventListener("input", function(e) {
        let value = this.value.replace(/\s+/g, "").replace(/[^0-9]/gi, "");
        let formatted = "";
        
        for (let i = 0; i < value.length && i < 16; i++) {
            if (i > 0 && i % 4 === 0) formatted += " ";
            formatted += value[i];
        }
        
        this.value = formatted;
    });

    // Formatear fecha de expiración
    document.getElementById("card-expiry")?.addEventListener("input", function(e) {
        let value = this.value.replace(/\s+/g, "").replace(/[^0-9]/gi, "");
        let formatted = "";
        
        for (let i = 0; i < value.length && i < 4; i++) {
            if (i === 2) formatted += "/";
            formatted += value[i];
        }
        
        this.value = formatted;
    });

    // Confirmar pago en efectivo
    document.getElementById("confirm-cash")?.addEventListener("click", function() {
        const btn = this;
        btn.innerHTML = '<i class="icon-spinner"></i> Generando código...';
        btn.disabled = true;
        
        setTimeout(() => {
            // Generar código de pago único
            const codigoPago = "EF-" + Math.random().toString(36).substr(2, 8).toUpperCase();
            
            // Guardar datos de la transacción
            const transaccion = {
                metodo: "efectivo",
                codigo: codigoPago,
                total: total,
                items: carrito,
                fecha: new Date().toISOString()
            };
            
            localStorage.setItem("ultimaTransaccion", JSON.stringify(transaccion));
            localStorage.removeItem("carritoCheckout");
            
            // Redirigir a confirmación
            window.location.href = "/op/FRONT/HTML/confirmacion.html";
        }, 1500);
    });

    // Validar formulario de tarjeta
    document.getElementById("payment-form")?.addEventListener("submit", function(e) {
        e.preventDefault();
        
        if (validarFormulario()) {
            procesarPago();
        }
    });
});

function actualizarOpcionesCuotas(total) {
    const opcionesCuotas = [
        { cuotas: 1, texto: "1 cuota de $" },
        { cuotas: 3, texto: "3 cuotas de $" },
        { cuotas: 6, texto: "6 cuotas de $" },
        { cuotas: 12, texto: "12 cuotas de $" }
    ];

    const select = document.getElementById("card-installments");
    select.innerHTML = '<option value="">Seleccione cuotas</option>';
    
    opcionesCuotas.forEach(opcion => {
        const montoCuota = (total / opcion.cuotas).toFixed(2);
        const option = document.createElement("option");
        option.value = opcion.cuotas;
        option.textContent = `${opcion.texto}${montoCuota}`;
        select.appendChild(option);
    });
}

function mostrarResumenCompra(carrito, total) {
    const orderSummary = document.getElementById("order-summary");
    let html = "";
    
    if (carrito.length === 0) {
        html = '<p>No hay productos en tu carrito</p>';
    } else {
        carrito.forEach(item => {
            html += `
                <div class="order-item">
                    <span class="order-item-name">${item.nombre} × ${item.cantidad}</span>
                    <span>$${(item.precio * item.cantidad).toLocaleString()}</span>
                </div>
            `;
        });
    }
    
    orderSummary.innerHTML = html;
    document.getElementById("subtotal").textContent = `$${total.toLocaleString()}`;
    document.getElementById("summary-total").textContent = `$${total.toLocaleString()}`;
}

function actualizarTotalPago(total) {
    document.getElementById("total-amount").textContent = total.toLocaleString();
}

function validarFormulario() {
    const metodo = document.querySelector(".payment-method.active").dataset.method;
    
    if (metodo === "credit" || metodo === "debit") {
        const cardNumber = document.getElementById("card-number").value.replace(/\s/g, "");
        const cardName = document.getElementById("card-name").value.trim();
        const cardExpiry = document.getElementById("card-expiry").value;
        const cardCvv = document.getElementById("card-cvv").value;
        
        if (cardNumber.length !== 16) {
            alert("Por favor ingrese un número de tarjeta válido (16 dígitos)");
            return false;
        }
        
        if (cardName.length < 3) {
            alert("Por favor ingrese el nombre como aparece en la tarjeta");
            return false;
        }
        
        if (!/^\d{2}\/\d{2}$/.test(cardExpiry)) {
            alert("Formato de fecha inválido. Use MM/AA");
            return false;
        }
        
        if (cardCvv.length !== 3) {
            alert("El CVV debe tener 3 dígitos");
            return false;
        }
        
        if (metodo === "credit" && !document.getElementById("card-installments").value) {
            alert("Por favor seleccione un plan de cuotas");
            return false;
        }
    }
    
    return true;
}

function procesarPago() {
    const btnPay = document.querySelector(".btn-pay");
    btnPay.disabled = true;
    btnPay.innerHTML = '<i class="icon-spinner"></i> Procesando pago...';

    // Mostrar spinner de carga
    const spinner = document.createElement('div');
    spinner.className = 'fullscreen-spinner';
    spinner.innerHTML = '<div class="spinner-content"><div class="spinner"></div><p>Procesando tu pago...</p></div>';
    document.body.appendChild(spinner);

    // Simular procesamiento de pago (2 segundos)
    const procesamiento = setTimeout(() => {
        const metodo = document.querySelector(".payment-method.active").dataset.method;
        const transaccion = {
            metodo: metodo,
            total: parseFloat(document.getElementById("total-amount").textContent.replace(/[^0-9.]/g, '')),
            items: JSON.parse(localStorage.getItem("carritoCheckout")),
            fecha: new Date().toISOString()
        };
        
        if (metodo === "credit" || metodo === "debit") {
            transaccion.tarjeta = {
                ultimos4: document.getElementById("card-number").value.slice(-4),
                tipo: metodo === "credit" ? "crédito" : "débito",
                cuotas: metodo === "credit" ? parseInt(document.getElementById("card-installments").value) : 1
            };
        }
        
        // Guardar transacción y limpiar carrito
        localStorage.setItem("ultimaTransaccion", JSON.stringify(transaccion));
        localStorage.removeItem("carritoCheckout");
        
        // Remover spinner
        document.body.removeChild(spinner);
        
        // Redirigir a página de confirmación
        window.location.href = "/op/FRONT/HTML/confirmacion.html";
    }, 2000);

    // Timeout de seguridad (10 segundos máximo)
    const timeoutSeguridad = setTimeout(() => {
        clearTimeout(procesamiento);
        document.body.removeChild(spinner);
        btnPay.disabled = false;
        btnPay.innerHTML = '<i class="icon-lock"></i> PAGAR $<span id="total-amount">0.00</span>';
        alert('El proceso está tomando más tiempo de lo normal. Por favor intenta nuevamente.');
    }, 10000);
}        
    
