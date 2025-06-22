class FormHandler {
  constructor({ formSelector, endpoint, messageTarget, onSuccess }) {
    this.form = document.querySelector(formSelector);
    this.endpoint = endpoint;
    this.messageTarget = messageTarget;
    this.onSuccess = onSuccess;

    if (!this.form) {
      console.error("Formulario no encontrado:", formSelector);
      return;
    }

    this.form.addEventListener("submit", (e) => this.handleSubmit(e));
  }

  async handleSubmit(e) {
    e.preventDefault();

    const data = this.getFormData();
    try {
      const response = await fetch(this.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(data),
      });

      const result = await response.json();

      let mensaje = result.mensaje || result.error || "No hay mensaje para mostrar";

      if (typeof mensaje === "object") {
        mensaje = JSON.stringify(mensaje, null, 2);
      }

      this.showMessage(mensaje, !!result.mensaje);

      if (result.mensaje) {
        this.form.reset();
        if (typeof this.onSuccess === "function") {
          this.onSuccess();
        }
      }
    } catch (error) {
      console.error("Error al enviar datos:", error);
      this.showMessage("Error de conexión o del servidor.", false);
    }
  }

  getFormData() {
    const inputs = this.form.querySelectorAll("input[name], textarea[name], select[name]");
    const data = {};
    inputs.forEach((input) => {
      if (input.type === "checkbox") {
        data[input.name] = input.checked;
      } else {
        data[input.name] = input.value.trim();
      }
    });
    return data;
  }

  showMessage(msg, success) {
    if (!this.messageTarget) {
      alert(msg);
      return;
    }

    if (typeof this.messageTarget === "function") {
      this.messageTarget(msg, success);
    } else if (this.messageTarget instanceof HTMLElement) {
      this.messageTarget.textContent = msg;
      this.messageTarget.style.color = success ? "green" : "red";
    } else {
      alert(msg);
    }
  }
}
