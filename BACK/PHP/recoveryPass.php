<?php
require_once "connection.php"; 
require_once "recoverPassModel.php";
require_once "loginModel.php";
$model = new recoverPassModel($conn);
$token = $_GET['token'] ?? '';
$login = new LoginModel($conn);

$data = $model->getTokenData($token);
$msg = '';
if (!$data) {
    echo "<h2>El enlace expiró o es inválido</h2>";
    exit;
}
$id_usuario = $data['id_usuario'];
$expires_at = $data['expires_at'];


if (strtotime($expires_at) < time()) {
    echo "<h2>El enlace expiró o es inválido</h2>";
    exit;
}


if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $newPass = trim($_POST['password'] ?? '');
    $confirm = trim($_POST['confirm'] ?? '');

    if ($newPass !== $confirm) {
        $msg = "Las contraseñas no coinciden";
    } elseif (strlen($newPass) < 8) {
        $msg = "La contraseña es demasiado corta";
    } else {
    
        $hashActual = $login->bringPassword($model->getUserEmailById($id_usuario));
        if ($hashActual && password_verify($newPass, $hashActual)) {
            $msg = "La nueva contraseña no puede ser igual a la anterior";
        } else {
            $hash = password_hash($newPass, PASSWORD_BCRYPT);
            $res = $model->changePasswordById($id_usuario, $hash);
            if ($res['success']) {
                $model->deleteToken($token);
                $msg = "Contraseña actualizada correctamente. <a href='../../FRONT/HTML/login.html'>Iniciar sesión</a>";
            } else {
                $msg = "Error al actualizar la contraseña: " . htmlspecialchars($res['error']);
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Recuperar Contraseña - ViajesMundo</title>
  <link rel="stylesheet" href="../../FRONT/CSS/form.css" />
  <link rel="stylesheet" href="../../FRONT/CSS/header-footer.css"/>
</head>
<body>
 <header class="site-header">
    <div class="container header-container">
      <h1>TRAVEL</h1>
      <nav class="main-nav">
        <ul class="nav-menu">
          <li><a href="index.html">Inicio</a></li>
          <li class="dropdown-parent">
            <button class="dropdown-toggle" aria-haspopup="true" aria-expanded="false">
              Paquetes <i class="fa-solid fa-chevron-down"></i>
            </button>
            <ul class="submenu">
              <li><a href="../../FRONT/HTML/coches.html">Alquiler de autos</a></li>
              <li><a href="../../FRONT/HTML/paquetes.html">Paquetes turisticos</a></li>
              <li><a href="../../FRONT/HTML/estadias.html">Estadias</a></li>
              <li><a href="../../FRONT/HTML/pasajes.html">Pasajes aéreos</a></li>
            </ul>
          </li>
          <li><a href="#contacto">Contacto</a></li>
        </ul>
      </nav>
      <div class="user-menu">
        <a href="carrito.html" aria-label="Ir al carrito de compras" class="icon-link">
          <i class="fa-solid fa-cart-shopping user-icon"></i>
        </a>
        <button id="user-menu-btn" aria-label="Menú de usuario" class="icon-btn">
          <i class="fa-solid fa-user user-icon"></i>
        </button>
        <ul class="dropdown">
          <li id="user"></li>
          <li id="panel_usuario"><a href="panel_usuario.html">Panel</a></li>
          <li id="login_panel"><a href="login.html">Iniciar sesión</a></li>
          <li id="register_panel"><a href="register.html">Registrarse</a></li>
          <li><a href="#" id="logout">Cerrar Sesion</a></li>
        </ul>
      </div>
    </div>
  </header>
  <main class="form-container">
    <h2>Recuperar contraseña</h2>
    <?php if ($msg): ?>
      <div class="msg" id="msg-recover" style="margin-bottom:1em;"><?= $msg ?></div>
    <?php endif; ?>
    <form method="post" id="recoverPassword" autocomplete="off">
      <label for="password">Contraseña:</label>
      <div class="password-wrapper" style="position: relative;">
        <input type="password" id="password" name="password" maxlength="16" required />
        <div id="password-rules">
          <p id="min-length">8 caracteres</p>
          <p id="lowercase">Una minúscula</p>
          <p id="uppercase">Una mayúscula</p>
          <p id="number">Un número</p>
          <p id="special">Un carácter especial @ # $ ^ & + = . ! ? - _ *</p>
        </div>
      </div>
      <label for="confirm">Confirmar contraseña:</label>
      <input type="password" id="confirm" name="confirm" required />
      <div class="show-password-container">
        <label for="showpassword">Mostrar Contraseña</label>
        <input type="checkbox" id="showpassword" name="showpass" onclick="togglePassword()">
      </div>
      <button type="submit">Entrar</button>
    </form>
    <script>
      function togglePassword() {
        var pass = document.getElementById('password');
        var conf = document.getElementById('confirm');
        var show = document.getElementById('showpassword').checked;
        pass.type = show ? 'text' : 'password';
        conf.type = show ? 'text' : 'password';
      }
    </script>
    <script src="../JS LOGICA/passParameters.js"></script>
    <script>
      // passParameters
      document.addEventListener("DOMContentLoaded", () => {
        new PasswordValidator({
          passwordSelector: "#password",
          confirmSelector: "#confirm",
          toggleSelector: "#showpassword",
          rulesContainerSelector: "#password-rules",
          formSelector: "#recoverPassword",
          ruleSelectors: {
            minLength: "#min-length",
            lowercase: "#lowercase",
            uppercase: "#uppercase",
            number: "#number",
            special: "#special"
          }
        });
          });
    </script>
    <script src="../../FRONT/JS DISEÑO/menu.js"></script>
  </main>
  <footer class="site-footer center">
    <p>&copy; 2025 ViajesMundo. Todos los derechos reservados.</p>
  </footer>
</body>
</html>
