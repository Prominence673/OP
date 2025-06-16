class FormHandler {
  constructor({ formSelector, endpoint }) {
    this.form = document.querySelector(formSelector);
    this.endpoint = endpoint;

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

      alert(result.mensaje || result.error);

      if (result.mensaje) {
        this.form.reset();
      }
    } catch (error) {
      console.error("Error al enviar datos:", error);
      alert("Error de conexión o del servidor.");
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
}