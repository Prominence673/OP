<?php
require_once 'connection.php';
require_once 'loginModel.php';
require_once 'registerModel.php';

$login = new LoginModel($conn);
$register = new registerModel($conn);
[$mail, $password] = $register->bringInput();

$hashGuardado = $login->bringPassword($mail);
$resultado = $login->verifyPassword($password, $hashGuardado);

echo json_encode($resultado);
?>