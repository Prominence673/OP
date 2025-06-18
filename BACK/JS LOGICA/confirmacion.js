document.addEventListener("DOMContentLoaded", function() {
    const transaccion = JSON.parse(localStorage.getItem("ultimaTransaccion")) || {};
    const orderDetails = document.getElementById("order-details-content");
    
    let html = `
        <p><strong>Método de pago:</strong> ${transaccion.metodo === "credit" ? "Tarjeta de Crédito" : 
          transaccion.metodo === "debit" ? "Tarjeta de Débito" : 
          transaccion.metodo === "cash" ? "Efectivo en Sucursal" : "No especificado"}</p>
    `;
    
    if (transaccion.metodo === "cash" && transaccion.codigo) {
        html += `<p><strong>Código de pago:</strong> ${transaccion.codigo}</p>`;
    }
    
    if (transaccion.tarjeta) {
        html += `
            <p><strong>Tarjeta terminada en:</strong> **** **** **** ${transaccion.tarjeta.ultimos4 || '0000'}</p>
            ${transaccion.tarjeta.tipo === "crédito" ? 
              `<p><strong>Cuotas:</strong> ${transaccion.tarjeta.cuotas || 1}</p>` : ''}
        `;
    }
    
    html += `
        <p><strong>Total:</strong> $${transaccion.total?.toLocaleString() || '0.00'}</p>
        <p><strong>Fecha:</strong> ${new Date(transaccion.fecha).toLocaleDateString()}</p>
    `;
    
    orderDetails.innerHTML = html;
    
    // Limpiar datos si ya se mostraron
    if (transaccion.metodo !== "cash") {
        localStorage.removeItem("ultimaTransaccion");
    }
});