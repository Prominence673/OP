class FileUploader {
  constructor({ formSelector, fileInputName, endpoint, messageTarget, onSuccess }) {
    this.form = document.querySelector(formSelector);
    this.endpoint = endpoint;
    this.messageTarget = messageTarget;
    this.fileInputName = fileInputName;
    this.onSuccess = onSuccess;

    if (!this.form) {
      console.error("Formulario no encontrado:", formSelector);
      return;
    }

    this.form.addEventListener("submit", (e) => this.uploadFile(e));
  }

  async uploadFile(e) {
    e.preventDefault();

    const formData = new FormData(this.form);

    if (!formData.get(this.fileInputName) || formData.get(this.fileInputName).size === 0) {
      this.showMessage("Seleccioná un archivo antes de subir.", false);
      return;
    }

    try {
      const response = await fetch(this.endpoint, {
        method: "POST",
        body: formData
      });

      const result = await response.json();

      const mensaje = result.mensaje || result.error || "Archivo enviado.";

      this.showMessage(mensaje, !!result.mensaje);

      if (result.mensaje && typeof this.onSuccess === "function") {
        this.onSuccess(result);
      }

    } catch (error) {
      console.error("Error al subir el archivo:", error);
      this.showMessage("Error al subir el archivo.", false);
    }
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