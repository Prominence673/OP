fetch('../../BACK/PHP/checkSession.php')
  .then(response => response.json())
  .then(data => {
    if (data.loggedIn) {
      document.getElementById('user').textContent = data.usuario.nombre;
    } else {
      document.getElementById('user').textContent = 'Invitado';
    }
  });