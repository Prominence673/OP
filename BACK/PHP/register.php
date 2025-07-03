<?php
require_once 'connection.php';    
require_once 'registerModel.php';      

$registro = new registerModel($conn);

[$user, $email, $password, $confirm] = $registro->bringInput();

$validacionInput = $registro->verifyInput($user, $email, $password, $confirm);
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
$validacionPassword = $registro->validarPasswordFuerte($password);

if (!$validacionPassword["valido"]) {
    echo json_encode(["error" => "Contraseña débil: " . implode(", ", $validacionPassword["errores"])]);
    exit;
}
$result = $registro->registerUser($user, $email, $hashPassword);

if ($result["success"]) {
    echo json_encode(["mensaje" => "Usuario registrado correctamente"]);
} else {
    echo json_encode(["error" => $result["error"] ?? "Error desconocido"]);
}
$registro->closeConn();
?>