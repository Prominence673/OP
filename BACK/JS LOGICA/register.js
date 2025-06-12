const form = document.getElementById("session");
 form.addEventListener('submit', async e => {
    e.preventDefault();
    const name = document.getElementById('name').value;
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const confirm = document.getElementById('confirm').value;

    const res = await fetch('http://localhost/OP/BACK/PHP/login.php', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, email, password, confirm })
    });
    const data = await res.json();
    alert(data.mensaje || data.error);
    form.reset();
  });
  