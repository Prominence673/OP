const form_login = document.getElementById("session");

form_login.addEventListener("submit", async (e) => {
  e.preventDefault(); 

    const email = document.getElementById("email").value.trim();
    const password = document.getElementById("password").value.trim();
  

  const data = { email, password };

  try {
    const response = await fetch("../../BACK/PHP/login.php", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    });

    const result = await response.json();

    alert(result.mensaje || result.error);
    
    if(result.mensaje){
      form_login.reset(); 
    }

  } catch (error) {
    console.error("Error al enviar datos:", error);
    alert("Error de conexión o del servidor.");
  }
});