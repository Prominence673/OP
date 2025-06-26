document.addEventListener("DOMContentLoaded", () => {
    const paymentMethods = document.querySelectorAll(".payment-method");

    const formCredit = document.getElementById("formCredit");
    const formDebit = document.getElementById("formDebit");
    const formEfec = document.getElementById("formEfec");

    const installmentsGroup = document.getElementById("installments-group");
    const totalAmountSpan = document.getElementById("total-amount");
    const subtotalSpan = document.getElementById("subtotal");
    const summaryTotalSpan = document.getElementById("summary-total");
    const orderSummary = document.getElementById("order-summary");
    const confirmCashBtn = document.getElementById("confirm-cash");

    const dniInput = document.getElementById("dni");
    const dniEfectivoInput = document.getElementById("dni_efectivo");
    const numeroTarjetaInput = document.getElementById("card-number");
    const cardExpiryInput = document.getElementById("card-expiry");
    const cvvInput = document.getElementById("card-cvv");

    let carrito = JSON.parse(localStorage.getItem("carrito")) || [];
    let total = 0;
    let metodoSeleccionado = "credit";

    function cargarResumen() {
        orderSummary.innerHTML = "";
        total = 0;

        carrito.forEach(item => {
            const itemTotal = item.precio * item.cantidad;
            total += itemTotal;

            const div = document.createElement("div");
            div.classList.add("summary-item");
            div.innerHTML = `
                <span>${item.nombre} x${item.cantidad}</span>
                <span>$${itemTotal.toFixed(2)}</span>
            `;
            orderSummary.appendChild(div);
        });

        subtotalSpan.textContent = `$${total.toFixed(2)}`;
        summaryTotalSpan.textContent = `$${total.toFixed(2)}`;
    }

    function mostrarFormularioPorMetodo(metodo) {
        metodoSeleccionado = metodo;

        if (formCredit) formCredit.style.display = "none";
        if (formDebit) formDebit.style.display = "none";
        if (formEfec) formEfec.style.display = "none";

        if (metodo === "credit" && formCredit) {
            formCredit.style.display = "block";
            if (installmentsGroup) installmentsGroup.style.display = "block";
        } else if (metodo === "debit" && formDebit) {
            formDebit.style.display = "block";
            if (installmentsGroup) installmentsGroup.style.display = "none";
        } else if (metodo === "cash" && formEfec) {
            formEfec.style.display = "block";
            if (installmentsGroup) installmentsGroup.style.display = "none";
        }
    }

    function validarNombreCampo(valor) {
        return /^[A-Za-zÁÉÍÓÚÑáéíóúñ\s]+$/.test(valor);
    }

    if (numeroTarjetaInput) {
        numeroTarjetaInput.addEventListener("input", e => {
            let value = e.target.value.replace(/\D/g, "").substring(0, 19);
            e.target.value = value.match(/.{1,4}/g)?.join(" ") || "";
        });
    }

    if (cardExpiryInput) {
        cardExpiryInput.addEventListener("input", e => {
            let value = e.target.value.replace(/\D/g, "");
            if (value.length >= 3) {
                e.target.value = `${value.slice(0, 2)}/${value.slice(2, 4)}`;
            } else {
                e.target.value = value;
            }
        });
    }

    if (cvvInput) {
        cvvInput.addEventListener("input", e => {
            e.target.value = e.target.value.replace(/\D/g, "").substring(0, 4);
        });
    }

    if (dniInput) {
        dniInput.addEventListener("input", e => {
            e.target.value = e.target.value.replace(/\D/g, "").substring(0, 8);
        });
    }

    if (dniEfectivoInput) {
        dniEfectivoInput.addEventListener("input", e => {
            e.target.value = e.target.value.replace(/\D/g, "").substring(0, 8);
        });
    }

    paymentMethods.forEach(btn => {
        btn.addEventListener("click", () => {
            const metodo = btn.dataset.method;
            paymentMethods.forEach(pm => pm.classList.remove("active"));
            btn.classList.add("active");
            mostrarFormularioPorMetodo(metodo);
        });
    });

    cargarResumen();
    mostrarFormularioPorMetodo("credit");
});
