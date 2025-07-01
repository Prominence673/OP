<?php
ini_set('display_errors', 0); 
ini_set('log_errors', 1); 
ini_set('error_log', __DIR__ . '/error_log.txt'); 
header('Content-Type: application/json'); 
require_once 'connection.php';
require_once 'user_panelModel.php';
require_once 'loginModel.php';
require_once 'registerModel.php';
require_once 'recoverPassModel.php';
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
$recover = new recoverPassModel($conn);
$userPanel = new userPanel($conn);
$login = new LoginModel($conn);
$register = new registerModel($conn);
$datos = $userPanel->bringInputFromForm();
$action = $datos['action'] ?? '';
try {
    switch ($action) {
        case 'guardar_datos':
            $datos = $userPanel->bringInputFromForm();
            $userPanel->uploadData(
                $datos['nombre'],
                $datos['apellido'],
                $datos['fecha_nacimiento'],
                $datos['genero'],
                $datos['dni'],
                $datos['provincia'],
                $datos['localidad'],
                $datos['partido'],
                $datos['codigo_postal']
            );
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
            $verificacion = $register->verifyMail($nuevo_email);

             if (!$verificacion['success']) {
                echo json_encode(["success" => false, "error" => $verificacion['error']]);
                break;
            }


            $token = $userPanel->generateToken();
            $expires = date('Y-m-d H:i:s', strtotime('+1 hour'));
            $userPanel->insertEmailResetToken($nuevo_email, $token, $expires);


            $resultadoEnvio = $userPanel->sendVerifyEmail($nuevo_email, $token);
            echo json_encode($resultadoEnvio);
            break;

        case 'cambiar_contra':
            $datos = $userPanel->bringInputFromForm();

            if ($datos['password'] !== $datos['confirmpassword']) {
                echo json_encode(["success" => false, "error" => "Las contraseñas no coinciden"]);
                break;
            }
            
            $hash_guardado = $login->bringPassword($_SESSION['usuario']['email']);
            if (!$hash_guardado || !password_verify($datos['currentpassword'], $hash_guardado)) {
                echo json_encode(["success" => false, "error" => "Contraseña actual incorrecta"]);
                break;
            }
            $validacionPassword = $register->validarPasswordFuerte($datos['password']);
            if (!$validacionPassword["valido"]) {
                echo json_encode(["success" => false, "error" => "Contraseña débil: " . implode(", ", $validacionPassword["errores"])]);
                break;
            }
            $nuevo_hash = password_hash($datos['password'], PASSWORD_BCRYPT);
            $actualizado = $recover->changePassword($_SESSION['usuario']['email'], $nuevo_hash); 
            if ($actualizado) {
                echo json_encode(["success" => true, "mensaje" => "Contraseña actualizada"]);
            } else {
                echo json_encode(["success" => false, "error" => "Error al actualizar la contraseña"]);
            }

            break;

        case 'traer_datos_personales':
            $datos = $userPanel->getDatosPersonales();
            echo json_encode(["success" => true, "datos" => $datos]);
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