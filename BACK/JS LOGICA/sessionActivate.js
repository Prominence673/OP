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
          el.style.opacity = this.disableConfig.opacity || "0.5";
          el.style.display = this.disableConfig.display || "none";
        });
      });
    } else if (!this.sessionData.loggedIn && this.activateConfig) {
      this.activateConfig.selectors.forEach(selector => {
        document.querySelectorAll(selector).forEach(el => {
          el.disabled = false;
          el.style.pointerEvents = this.activateConfig.pointer || "auto";
          el.style.opacity = this.activateConfig.opacity || "1";
          el.style.display = this.disableConfig.display || "none";
        });
      });
    }
  }

  Disabled(selectors, pointer = "none", opacity = "0.5", display = "none") {
    this.disableConfig = {
      selectors,
      pointer,
      opacity
    };
  }

  Activate(selectors, pointer = "auto", opacity = "1", display = "") {
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

      const valorPorDefecto = "Inicia Sesión";

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
      AdminOnlyToggle(adminSelectors = [], nonAdminSelectors = []) {
  fetch("../../BACK/PHP/checkSession.php")
    .then(response => response.json())
    .then(data => {
      if (!data.loggedIn || !data.usuario) {
        console.warn("Usuario no logueado o datos no disponibles");
        return;
      }

      const isAdmin = data.usuario.id_rol === 1;
      console.log("¿Es admin?:", data.usuario.id_rol); // DEBUG
      if (isAdmin) {
        // Mostrar elementos solo para admin
        adminSelectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(el => {
            el.disabled = false;
            el.style.display = "";
            el.style.pointerEvents = "auto";
            el.style.opacity = "1";
          });
        });

        // Ocultar elementos solo para usuarios comunes
        nonAdminSelectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(el => {
            el.disabled = true;
            el.style.display = "none";
            el.style.pointerEvents = "none";
            el.style.opacity = "0.5";
          });
        });

      } else {
        // Mostrar elementos solo para usuarios comunes
        nonAdminSelectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(el => {
            el.disabled = false;
            el.style.display = "";
            el.style.pointerEvents = "auto";
            el.style.opacity = "1";
          });
        });

        // Ocultar elementos de admin
        adminSelectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(el => {
            el.disabled = true;
            el.style.display = "none";
            el.style.pointerEvents = "none";
            el.style.opacity = "0.5";
          });
        });
      }
    })
    .catch(error => {
      console.error("Error al verificar rol de usuario:", error);
    });
}
  
}
