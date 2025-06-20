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
  InsertData(Elementonombre, dato) {
  const elemento = document.getElementById(Elementonombre);
  if (!elemento) {
    console.warn(`Elemento con ID "${Elementonombre}" no encontrado.`);
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
      if (!data || typeof data !== "object" || !data.usuario) {
        throw new Error("La respuesta no contiene datos de usuario.");
      }

      if (!data.loggedIn) {
        console.warn("Usuario no logueado.");
        return;
      }

      const datosDisponibles = data.usuario;
      
      if (dato in datosDisponibles) {
        if(elemento.nodeName == "INPUT"){
          elemento.value = datosDisponibles[dato];
        }
        else{
          elemento.textContent = datosDisponibles[dato];
        }
        
      } else {
        console.warn(`Dato "${dato}" no encontrado en usuario.`);
      }
    })
    .catch(error => {
      console.error("Error al obtener datos de sesión:", error);
    });
}
}
