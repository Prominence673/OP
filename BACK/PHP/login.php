<?php
ini_set('display_errors', 0);   
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log'); 
require_once 'connection.php';
require_once 'loginModel.php';

$login = new LoginModel($conn);
[$mail, $password] = $login->bringInput();

$hashGuardado = $login->bringPassword($mail);
$resultado = $login->verifyPassword($password, $hashGuardado);

echo json_encode($resultado);
$login->closeConn();
?>