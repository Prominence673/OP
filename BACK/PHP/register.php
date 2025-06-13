<?php
require_once 'connection.php';    
require_once 'registerModel.php';      

$registro = new registerModel($conn);  

[$name, $mail, $password, $confirm] = $registro->bringInput();

$validacionInput = $registro->verifyInput($name, $mail, $password, $confirm);
if (!$validacionInput["success"]) {
    echo json_encode(["error" => $validacionInput["error"]]);
    exit;
}

$validacionEmail = $registro->verifyMail($mail);
if (!$validacionEmail["success"]) {
    echo json_encode(["error" => $validacionEmail["error"]]);
    exit;
}

$hashPassword = $registro->hashPassword($password);

$registro->registerUser($name, $mail, $hashPassword);
?>