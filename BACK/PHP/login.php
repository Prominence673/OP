<?php
require_once 'connection.php';
require_once 'loginModel.php';

$login = new LoginModel($conn);
[$mail, $password] = $login->bringInput();

$hashGuardado = $login->bringPassword($mail);
$resultado = $login->verifyPassword($password, $hashGuardado);

echo json_encode($resultado);
$login->closeConn();
?>