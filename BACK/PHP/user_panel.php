<?php
ini_set('display_errors', 0); 
ini_set('log_errors', 1); 
ini_set('error_log', __DIR__ . '/error_log.txt'); 
header('Content-Type: application/json'); 
require_once 'connection.php';
require_once 'user_panelModel.php';
require_once 'loginModel.php';
require_once 'registerModel.php';
$userPanel = new userPanel($conn);
$login = new LoginModel($conn);
$register = new registerModel($conn);
$datos = $userPanel->bringInputFromForm();
$action = $datos['action'] ?? '';
try {
    switch ($action) {
        case 'guardar_datos':
            $datos = $userPanel->bringInputFromForm();
            $userPanel->uploadData($datos['nombre'], $datos['apellido'], $datos['fecha_nacimiento'], $datos['genero']);
            echo json_encode(["success" => true, "mensaje" => "Datos personales actualizados"]);
            break;

        case 'guardar_telefono':
            $datos = $userPanel->bringInputFromForm();
            $userPanel->uploadPhone($datos['telefono']);
            echo json_encode(["success" => true, "mensaje" => "Teléfono actualizado"]);
            break;

        case 'verificar_email':
            $datos = $userPanel->bringInputFromForm();
            $token = $userPanel->generateToken();
            session_start();
            $expires = date('Y-m-d H:i:s', strtotime('+1 hour'));
            $userPanel->insertToken($_SESSION['usuario']['email'], $token, $expires);
            $resultadoEnvio = $userPanel->sendVerifyEmail($_SESSION['usuario']['email'], $token);
            echo json_encode($resultadoEnvio);
            break;

        case 'guardar_email':
            $datos = $userPanel->bringInputFromForm();
            $nuevo_email = $datos['email'];


            if (!$register->verifyMail($nuevo_email)) {
                echo json_encode(["success" => false, "error" => "El email ya está en uso"]);
                break;
            }


            $token = $userPanel->generateToken();
            $expires = date('Y-m-d H:i:s', strtotime('+1 hour'));
            $userPanel->insertEmailResetToken($nuevo_email, $token, $expires);


            $resultadoEnvio = $userPanel->sendVerifyEmail($nuevo_email, $token);
            echo json_encode($resultadoEnvio);
            break;

        case 'cambiar_contraseña':
            $datos = $userPanel->bringInputFromForm();

            if ($datos['password'] !== $datos['confirmpassword']) {
                echo json_encode(["success" => false, "error" => "Las contraseñas no coinciden"]);
                break;
            }

            $hash_guardado = $login->bringPassword($datos['email']);
            if (!password_verify($datos['currentpassword'], $hash_guardado)) {
                echo json_encode(["success" => false, "error" => "Contraseña actual incorrecta"]);
                break;
            }
            $validacionPassword = $registro->validarPasswordFuerte($datos['password']);
            $validacionPassword = $register->validarPasswordFuerte($datos['password']);
            if (!$validacionPassword["valido"]) {
                echo json_encode(["error" => "Contraseña débil: " . implode(", ", $validacionPassword["errores"])]);
                break;
            }
            $userPanel->updatePassword($nuevo_hash);
            echo json_encode(["success" => true, "mensaje" => "Contraseña actualizada"]);
            break;

        default:
            echo json_encode(["success" => false, "error" => "Acción no válida"]);
            break;
    }
} catch (Exception $e) {
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
} finally {
    $userPanel->closeConn();
    exit;
}