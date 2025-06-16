<?php
ini_set('display_errors', 0);   
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log'); 
require_once 'connection.php';    
require_once 'registerModel.php';      

$registro = new registerModel($conn);

[$name, $email, $password, $confirm] = $registro->bringInput();

$validacionInput = $registro->verifyInput($name, $email, $password, $confirm);
if (!$validacionInput["success"]) {
    echo json_encode(["error" => $validacionInput["error"]]);
    exit;
}

$validacionEmail = $registro->verifyMail($email);
if (!$validacionEmail["success"]) {
    echo json_encode(["error" => $validacionEmail["error"]]);
    exit;
}

$hashPassword = $registro->hashPassword($password);

$result = $registro->registerUser($name, $email, $hashPassword);

if ($result["success"]) {
    echo json_encode(["mensaje" => "Usuario registrado correctamente"]);
} else {
    echo json_encode(["error" => $result["error"] ?? "Error desconocido"]);
}
$registro->closeConn();
?>