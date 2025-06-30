<?php
require_once "connection.php"; 
require_once "user_panelModel.php";
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
$model = new userPanel($conn);
$token = $_GET['token'] ?? '';


$data = $model->getTokenData($token);
$msg = '';
if (!$data) {
    echo "<h2>El enlace expiró o es inválido</h2>";
    exit;
}
$id_usuario = $data['id_usuario'];
$new_mail = $data['nuevo_email'];
$expires_at = $data['expires_at'];


if (strtotime($expires_at) < time()) {
    echo "<h2>El enlace expiró o es inválido</h2>";
    exit;
}
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!($new_mail && $id_usuario && $expires_at)) {
        $msg = "No se proporcionaron los datos necesarios";
        exit;
    }
    $stmt = $conn->prepare("CALL SPResetEmail(?, ?)");
    $stmt->bind_param("ss", $token, $new_mail);
    if ($stmt->execute()) {
        $stmt->close();
        $exito = true;
        $model->setUsuarioVerificado($id_usuario, $exito);
        $model->deleteToken($token);
        $msg = "Correo verificado correctamente. <a href='../../FRONT/HTML/login.html'>Iniciar sesión</a>";
        $_SESSION['usuario']['email'] = $new_mail;
        $_SESSION['usuario']['verificado'] = true;
    } else {
        $msg = "Error al verificar el correo.";
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
  <main class="form-container" style="witdh: 100%; max-width: 600px; margin: auto; ">
    <form method="post" id="verifyEmail">
      <div>
        <p>Verifica el correo electronico asi podremos asegurarnos que eres el propietario del correo electronico.</p>
      </div>
      <button type="submit">Verificar Correo</button>
    </form>
    <script src="../../FRONT/JS DISEÑO/menu.js"></script>
  </main>
  <footer class="site-footer center">
    <p>&copy; 2025 ViajesMundo. Todos los derechos reservados.</p>
  </footer>
</body>
</html>
