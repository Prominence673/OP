<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/../vendor/autoload.php'; 
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/../');
$dotenv->load();

class recoverPassModel {
    private $conn;

    public function __construct($conn) {
        $this->conn = $conn;
        mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    }

    public function verifyMail($email) {
        if ($email === '') return ["success" => false, "error" => "Completar todos los campos"];
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) return ["success" => false, "error" => "Email inválido"];
        return ["success" => true];
    }

    public function bringInput() {
        $raw = file_get_contents("php://input");
        $datos = json_decode($raw, true);
        if (!$datos) {
            echo json_encode(["error" => "No se pudo decodificar JSON"]);
            exit;
        }
        $email = trim($datos['email'] ?? '');
        return [$email];
    }

    public function userCheck($email) {
        try {
            $stmt = $this->conn->prepare("CALL SPUserExists(?)");
            $stmt->bind_param("s", $email);
        
            $stmt->execute();
            $resultado = $stmt->get_result();
            $usuario = $resultado->fetch_assoc();
            $stmt->close();

            if (!$usuario) {
                return ["success" => false, "error" => "No hay cuenta vinculada con el correo"];
            }
            return ["success" => true];
        } catch (mysqli_sql_exception $e) {
            return ["success" => false, "error" => "Error en la consulta: " . $e->getMessage()];
        }
    }

    public function generateToken() {
        return bin2hex(random_bytes(32));
    }

    public function insertToken($email, $token, $expires) {
        $stmt = $this->conn->prepare("CALL SPInsertPasswordReset((SELECT id_usuario FROM usuarios WHERE email = ?), ?, ?)");
        $stmt->bind_param("sss", $email, $token, $expires);
        $stmt->execute();
        $stmt->close();
    }

    public function getTokenData($token) {
        $stmt = $this->conn->prepare("CALL SPGetPasswordResetByToken(?)");
        $stmt->bind_param("s", $token);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        $stmt->close();
        return $data ?: null;
    }

    public function changePassword($email, $hash_password) {
        try {
            $stmt = $this->conn->prepare("CALL SPChangePassword(?, ?)");
            $stmt->bind_param("ss", $email, $hash_password);
            $stmt->execute();
            return ($stmt->affected_rows > 0) ? ["success" => true] : ["success" => false, "error" => "No se actualizó la contraseña"];
        } catch (mysqli_sql_exception $e) {
            return ["success" => false, "error" => "Excepción: " . $e->getMessage()];
        }
    }
    public function deleteToken($token) {
        $stmt = $this->conn->prepare("DELETE FROM password_resets WHERE token = ?");
        $stmt->bind_param("s", $token);
        $stmt->execute();
        $stmt->close();
    }

    public function sendRecoveryEmail($email, $token) {
        $mail = new PHPMailer(true);
        try {
            $mail->isSMTP();
            $mail->Host = 'smtp.gmail.com';
            $mail->SMTPAuth = true;
            $mail->Username = $_ENV['EMAIL_USER'];
            $mail->Password = $_ENV['EMAIL_PASS'];
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port = 587;

            $mail->setFrom($_ENV['EMAIL_USER'], 'Soporte KAPIFLY');
            $mail->addAddress($email);

            $mail->isHTML(true);
            $mail->Subject = 'Password recovery - KAPIFLY';

            $recoveryLink = "http://localhost/OP/BACK/PHP/recoveryPass.php?token=" . urlencode($token);

            $mail->Body = "
            <div style='font-family: Arial, sans-serif; max-width: 600px; margin: auto; border-radius: 8px; overflow: hidden;'>
                <div style='background-color: #0077cc; height: 50px;'></div>
                <div style='background-color: #ffffff; padding: 40px; text-align: center;'>
                    <h2 style='color: #333;'>Recuperación de contraseña</h2>
                    <p style='color: #555;'>Hola, recibimos una solicitud para restablecer tu contraseña.</p>
                    <p style='color: #555;'>Haz clic en el botón de abajo para continuar:</p>
                    <a href='$recoveryLink' style='display: inline-block; margin-top: 20px; padding: 10px 20px; background-color: #0077cc; color: #fff; text-decoration: none; font-weight: bold; border-radius: 4px;'>Recuperar</a>
                </div>
                <div style='background-color: #0077cc; height: 50px;'></div>
            </div>";

            $mail->send();
            return ["success" => true, "mensaje" => "Correo enviado con éxito"];
        } catch (Exception $e) {
            return ["success" => false, "error" => "No se pudo enviar el correo: {$mail->ErrorInfo}"];
        }
    }

    public function getUserEmailById($id_usuario) {
        $stmt = $this->conn->prepare("SELECT email FROM usuarios WHERE id_usuario = ?");
        $stmt->bind_param("i", $id_usuario);
        $stmt->execute();
        $res = $stmt->get_result();
        $row = $res->fetch_assoc();
        $stmt->close();
        return $row ? $row['email'] : null;
    }

    public function closeConn() {
        $this->conn->close();
    }
}
?>
