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
$datos = $userPanel->bringInputFromForm();
$action = $datos['action'] ?? '';
$login = new LoginModel($conn);
$register = new registerModel($conn);

session_start(); 

try {
    switch ($action) {
        case 'guardar_foto':
            $ruta = $userPanel->uploadFile();
            if ($ruta) {
                echo json_encode(["success" => true, "mensaje" => "Imagen subida correctamente", "ruta" => $ruta]);
            } else {
                echo json_encode(["success" => false, "error" => "Error al subir imagen"]);
            }
            break;

        case 'guardar_datos':
            $datos = $userPanel->bringInputFromForm();
            $userPanel->uploadData($datos['nombre'], $datos['apellido'], $datos['fecha_nacimiento'], $datos['genero']);

            // Guardar en cookies y sesión
            setcookie('nombre', $datos['nombre'], time() + 86400, "/");
            setcookie('apellido', $datos['apellido'], time() + 86400, "/");
            setcookie('fecha_nacimiento', $datos['fecha_nacimiento'], time() + 86400, "/");
            setcookie('genero', $datos['genero'], time() + 86400, "/");

            $_SESSION['usuario']['nombre'] = $datos['nombre'];
            $_SESSION['usuario']['apellido'] = $datos['apellido'];
            $_SESSION['usuario']['genero'] = $datos['genero'];
            $_SESSION['usuario']['fecha_nacimiento'] = $datos['fecha_nacimiento'];

            echo json_encode(["success" => true, "mensaje" => "Datos personales actualizados"]);
            break;

        case 'guardar_telefono':
            $datos = $userPanel->bringInputFromForm();
            $userPanel->uploadPhone($datos['telefono']);

            // Guardar en cookie y sesión
            setcookie('telefono', $datos['telefono'], time() + 86400, "/");
            $_SESSION['usuario']['telefono'] = $datos['telefono'];

            echo json_encode(["success" => true, "mensaje" => "Teléfono actualizado"]);
            break;

        case 'verificar_email':
            $datos = $userPanel->bringInputFromForm();
            $token = $userPanel->generateToken();
            $expires = date('Y-m-d H:i:s', strtotime('+1 hour'));

            $email = $_SESSION['usuario']['email'];
            $userPanel->insertToken($email, $token, $expires);
            $resultadoEnvio = $userPanel->sendVerifyEmail($email, $token);
            echo json_encode($resultadoEnvio);
            break;

        case 'guardar_email':
            $datos = $userPanel->bringInputFromForm();
            $register->verifyMail($datos['email']);
            $userPanel->updateEmail($datos['email']);

            // Actualizar en cookie y sesión
            setcookie('email', $datos['email'], time() + 86400, "/");
            $_SESSION['usuario']['email'] = $datos['email'];

            echo json_encode(["success" => true, "mensaje" => "Email actualizado"]);

            // Enviar verificación también
            $token = $userPanel->generateToken();
            $expires = date('Y-m-d H:i:s', strtotime('+1 hour'));
            $userPanel->insertToken($datos['email'], $token, $expires);
            $resultadoEnvio = $userPanel->sendVerifyEmail($datos['email'], $token);
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

            //$validacionPassword = $register->validarPasswordFuerte($datos['password']);
            if (!$validacionPassword["valido"]) {
                echo json_encode(["error" => "Contraseña débil: " . implode(", ", $validacionPassword["errores"])]);
                break;
            }

            $nuevo_hash = password_hash($datos['password'], PASSWORD_DEFAULT);
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