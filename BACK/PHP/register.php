<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

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
    // 1. Buscar el id del usuario recién creado
    $id_usuario = $registro->getUserIdByEmail($email);
    if (!$id_usuario) {
        $respuesta = ["error" => "No se pudo obtener el ID del usuario recién registrado."];
    } else {
        // 2. Crear token único
        $token = bin2hex(random_bytes(32));
        $expires_at = date('Y-m-d H:i:s', strtotime('+1 day'));

        // 3. Guardar el token en la tabla de tokens
        try {
            $registro->insertEmailToken($id_usuario, $email, $token, $expires_at);
        } catch (Exception $e) {
            $respuesta = ["error" => "No se pudo guardar el token de verificación: " . $e->getMessage()];
            header('Content-Type: application/json');
            echo json_encode($respuesta);
            $registro->closeConn();
            exit;
        }

        // 4. Enviar email de verificación
        try {
            require_once 'user_panelModel.php';
            $userPanel = new userPanel($conn);
            $userPanel->sendVerifyEmail($email, $token);
        } catch (Exception $e) {
            $respuesta = ["error" => "No se pudo enviar el email de verificación: " . $e->getMessage()];
            header('Content-Type: application/json');
            echo json_encode($respuesta);
            $registro->closeConn();
            exit;
        }

        $respuesta = ["mensaje" => "Usuario registrado correctamente. Revisa tu correo para verificar tu cuenta."];
    }
} else {
    $respuesta = ["error" => $result["error"] ?? "Error desconocido"];
}

header('Content-Type: application/json');
echo json_encode($respuesta);
$registro->closeConn();
exit;
?>