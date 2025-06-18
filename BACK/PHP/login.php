<?php
require_once 'connection.php';
require_once 'loginModel.php';

$login = new LoginModel($conn);
[$mail, $password, $rememberme] = $login->bringInput();

if (!$mail || !$password) {
    echo json_encode([
        "success" => false,
        "error" => "Email y contraseña son obligatorios"
    ]);
    exit;
}

$hashGuardado = $login->bringPassword($mail);
$resultado = password_verify($password, $hashGuardado);

if ($resultado !== true) {
    echo json_encode(["success" => false,
        "error" => "Error"]);
    exit;
}

if ($rememberme) {
    $lifetime = 7 * 24 * 60 * 60; 
    session_set_cookie_params([
        'lifetime' => $lifetime,
        'path' => '/',
        'secure' => false,   
        'httponly' => true,
        'samesite' => 'Lax'
    ]);
}

session_start();

$id_user = $login->bringUser($mail);

$_SESSION['usuario'] = [
    "id" => $id_user['id'],
    "nombre" => $id_user['nombre'],
    "email" => $mail
];

$login->closeConn();

echo json_encode(["success" => true,
        "mensaje" => "Inicio de sesion exitoso"]);
?>