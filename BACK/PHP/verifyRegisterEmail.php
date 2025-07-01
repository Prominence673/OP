<?php
require_once "connection.php";
require_once "user_panelModel.php";

$model = new userPanel($conn);
$token = $_GET['token'] ?? '';

$data = $model->getTokenData($token);
$msg = '';

if (!$data) {
    $msg = "El enlace expiró o es inválido.";
} else {
    $id_usuario = $data['id_usuario'];
    $expires_at = $data['expires_at'];

    if (strtotime($expires_at) < time()) {
        $msg = "El enlace expiró o es inválido.";
    } else {
        // Marcar usuario como verificado
        $model->setUsuarioVerificado($id_usuario, true);
        // Eliminar el token
        $model->deleteToken($token);
        $msg = "¡Correo verificado correctamente! <a href='../../FRONT/HTML/login.html'>Iniciar sesión</a>";
    }
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Verificar Correo - ViajesMundo</title>
  <link rel="stylesheet" href="../../FRONT/CSS/form.css" />
  <link rel="stylesheet" href="../../FRONT/CSS/header-footer.css"/>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
  <header class="site-header">
    <div class="container header-container">
        <div class="logo-titulo">
          <a href="index.html">
            <img src="../../SOURCE/KAPIFLY.png" alt="Logo Kapifly" class="logo-img-real">
          </a>
        </div>
      <nav class="main-nav">
        <ul class="nav-menu">
          <li><a href="index.html">Inicio</a></li>
          <li class="dropdown-parent">
            <button class="dropdown-toggle" aria-haspopup="true" aria-expanded="false">
              Paquetes <i class="fa-solid fa-chevron-down"></i>
            </button>
            <ul class="submenu">
              <li><a href="coches.html">Alquiler coches</a></li>
              <li><a href="paquetes.html">Paquetes turisticos</a></li>
              <li><a href="estadias.html">Estadias</a></li>
              <li><a href="pasajes.html">Pasajes aéreos</a></li>
            </ul>
          </li>
          <li><a href="contacto.html">Contacto</a></li>
        </ul>
      </nav>
      <div class="user-menu">
        <a href="carrito.html" aria-label="Ir al carrito de compras" class="icon-link">
          <i class="fa-solid fa-cart-shopping user-icon"></i>
        </a>
        <button id="toggle-dark" class="darkmode-toggle" aria-label="Cambiar modo oscuro">
            <i class="fa-solid fa-moon" id="darkmode-icon"></i>
          </button>
          <ul class="dropdown">
            <li id="user"></li>
            <li id="panel_usuario"><a href="panel_usuario.html">Panel</a></li>
          <li id="panel_admin" style="display: none;"><a href="admin.html">Panel Admin</a></li>
          <li id="login_panel"><a href="login.html">Iniciar sesión</a></li>
          <li id="register_panel"><a href="register.html">Registrarse</a></li>
          <li><a href="#" id="logout">Cerrar Sesion</a></li>
        </ul>
      </div>
    </div>
  </header>
  <main class="form-container" style="width: 100%; max-width: 600px; margin: auto;">
    <div class="msg"><?= $msg ?></div>
  </main>
<footer class="site-footer">
  <div class="footer-container">
    <div class="footer-brand">
      <img src="../../SOURCE/KAPIFLY.png" alt="KAPIFLY Logo" class="footer-logo-img" style="height:48px;">      
      <span class="footer-desc">Viajes y experiencias únicas</span>
    </div>
    <div class="footer-links">
      <a href="../HTML/contacto.html" class="footer-link">Contacto</a>
      <a href="#" class="footer-link">Términos</a>
      <a href="#" class="footer-link">Privacidad</a>
      <a href="../HTML/contacto.html" class="footer-link">Preguntas frecuentes</a>
    </div>
    <div class="footer-social">
      <a href="#" class="footer-social-link" title="Twitter"><i class="fab fa-twitter"></i></a>
      <a href="#" class="footer-social-link" title="Instagram"><i class="fab fa-instagram"></i></a>
      <a href="#" class="footer-social-link" title="Tiktok"><i class="fab fa-tiktok"></i></a>
    </div>
  </div>
  <div class="footer-bottom">
    <p>&copy; 2025 KAPIFLY. Todos los derechos reservados.</p>
  </div>
</footer>
<script src="../JS DISEÑO/menu.js"></script>
</body>
</html>