const form_register = document.getElementById("register");

form_register.addEventListener("submit", async (e) => {
  e.preventDefault(); 

  const name = document.getElementById("name").value.trim();
  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value.trim();
  const confirm = document.getElementById("confirm").value.trim();

  const data = { name, email, password, confirm };

  try {
    const response = await fetch("../../BACK/PHP/register.php", {
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