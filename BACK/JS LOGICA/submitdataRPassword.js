const form_register = document.getElementById("recoverPassword");

form_register.addEventListener("submit", async (e) => {
  e.preventDefault(); 


  const email = document.getElementById("email").value.trim();
  const data = { email };

  try {
    const response = await fetch("../../BACK/PHP/recoverPassword.php", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    });

    const result = await response.json();

    alert(result.mensaje || result.error);
    
    if(result.mensaje){
      form_register.reset(); 
    }

  } catch (error) {
    console.error("Error al enviar datos:", error);
    alert("Error de conexión o del servidor.");
  }
});