class SessionActions {
  constructor() {
    this.sessionData = null;
    this.disableConfig = null;
    this.activateConfig = null;
    document.addEventListener("DOMContentLoaded", () => this.init());
  }

  init() {
    fetch("../../BACK/PHP/checkSession.php")
      .then(response => response.json())
      .then(data => {
        this.sessionData = data;
        this.runActions();
      })
      .catch(error => {
        console.error("Error al verificar sesión:", error);
      });
  }
   checkSessionAndRedirectIfLoggedIn(redirectUrl) {
    document.addEventListener("DOMContentLoaded", () => {
      fetch("../../BACK/PHP/checkSession.php")
        .then(response => response.json())
        .then(data => {
          if (data.loggedIn) {
            window.location.href = redirectUrl;
          }
        })
        .catch(error => {
          console.error("Error al verificar sesión:", error);
        });
    });
  }

  checkSessionAndRedirectIfNotLoggedIn(redirectUrl) {
    document.addEventListener("DOMContentLoaded", () => {
      fetch("../../BACK/PHP/checkSession.php")
        .then(response => response.json())
        .then(data => {
          if (!data.loggedIn) {
            window.location.href = redirectUrl;
          }
        })
        .catch(error => {
          console.error("Error al verificar sesión:", error);
        });
    });
  }
  runActions() {
    if (this.sessionData && this.sessionData.loggedIn && this.disableConfig) {
      this.disableConfig.selectors.forEach(selector => {
        document.querySelectorAll(selector).forEach(el => {
          el.disabled = true;
          el.style.pointerEvents = this.disableConfig.pointer || "none";
          el.style.disabled = this.disableConfig.opacity || "0.5";
        });
      });
    } else if (!this.sessionData.loggedIn && this.activateConfig) {
      this.activateConfig.selectors.forEach(selector => {
        document.querySelectorAll(selector).forEach(el => {
          el.disabled = false;
          el.style.pointerEvents = this.activateConfig.pointer || "auto";
          el.style.opacity = this.activateConfig.opacity || "1";
        });
      });
    }
  }

  Disabled(selectors, pointer = "none", opacity = "0.5") {
    this.disableConfig = {
      selectors,
      pointer,
      opacity
    };
  }

  Activate(selectors, pointer = "auto", opacity = "1") {
    this.activateConfig = {
      selectors,
      pointer,
      opacity
    };
  }
  setElementoValor(elemento, valor) {
  if (elemento.nodeName === "INPUT") {
    elemento.value = valor;
  } else {
    elemento.textContent = valor;
  }
  }
  InsertData(selector, dato) {
  const elementos = document.querySelectorAll(selector);
  
  if (elementos.length === 0) {
    console.warn(`No se encontraron elementos con el selector "${selector}".`);
    return;
  }

  fetch("../../BACK/PHP/checkSession.php")
    .then(response => {
      if (!response.ok) {
        throw new Error("Respuesta del servidor no válida.");
      }
      return response.json();
    })
    .then(data => {
      if (!data || typeof data !== "object") {
        throw new Error("La respuesta de sesión no es válida.");
      }

      const valorPorDefecto = "Invitado";

      if (!data.loggedIn || !data.usuario) {
        console.warn("Usuario no logueado o sin datos.");
        elementos.forEach(el => this.setElementoValor(el, valorPorDefecto));
        return;
      }

      const datosDisponibles = data.usuario;
      const valor = dato in datosDisponibles ? datosDisponibles[dato] : valorPorDefecto;

      elementos.forEach(el => this.setElementoValor(el, valor));
    })
    .catch(error => {
      console.error("Error al obtener datos de sesión:", error);
    });
  }
  logoutSession(){
      fetch("../../BACK/PHP/logoutSession.php")
      .then(() => window.location.href = "../../FRONT/HTML/login.html");
      };
  
}
