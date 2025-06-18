<?php
require_once 'connection.php';    
require_once 'recoverPassModel.php';

$recover = new recoverPassModel($conn);

[$email] = $recover->bringInput();

$validacionEmail = $recover->verifyMail($email);
if (!$validacionEmail["success"]) {
    echo json_encode(["success" => false, "error" => $validacionEmail["error"]]);
    exit;
}

$usuarioCheck = $recover->userCheck($email);
if (!$usuarioCheck["success"]) {
    echo json_encode(["success" => false, "error" => $usuarioCheck["error"]]);
    exit;
}

$token = $recover->generateToken();
$expires = date('Y-m-d H:i:s', strtotime('+1 hour'));

try {
    $recover->insertToken($email, $token, $expires);
} catch (Exception $e) {
    echo json_encode(["success" => false, "error" => "Error al guardar el token"]);
    exit;
}

$resultadoEnvio = $recover->sendRecoveryEmail($email, $token);
echo json_encode($resultadoEnvio);

$recover->closeConn();
exit;