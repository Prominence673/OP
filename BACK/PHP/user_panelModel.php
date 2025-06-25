<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once __DIR__ . '/../vendor/autoload.php'; 
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/../');
$dotenv->load();
class userPanel {
  private $conn;

  public function __construct($conn) {
    $this->conn = $conn;
  }
  private function ensureSessionStarted() {
  if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
  }
  }
  public function closeConn() {
    $this->conn->close();
  } 
  public function passwordVerify($contraseña_nueva, $contraseña_confirmacion) {
     if($contraseña_nueva !== $contraseña_confirmacion) {
        echo json_encode(["success" => false, "error" => "Las contraseñas no coinciden."]);
        exit;
      
    }
  }
  public function bringInputFromForm() {
    $raw = file_get_contents("php://input");
    $datos = json_decode($raw, true);
      if (!is_array($datos)) {
            return [null, null, null];
        }

    $nombre = $datos['name'] ?? '';
    $apellido = $datos['surname'] ?? '';
    $dia = $datos['dia'] ?? '';
    $mes = $datos['mes'] ?? '';
    $anio = $datos['anio'] ?? '';
    $genero = $datos['genero'] ?? '';
    $telefono = trim($datos['telefono'] ?? '');
    $email = trim($datos['email'] ?? '');
    $action = $datos['action'] ?? '';
    $contraseña_actual = trim($datos['currentpassword'] ?? '');
    $contraseña_nueva = trim($datos['password'] ?? '');
    $contraseña_confirmacion = trim($datos['confirmpassword'] ?? '');

    $fecha_nacimiento = '';
    if ($dia && $mes && $anio) {
      $fecha_nacimiento = "$anio-$mes-$dia";
    }

    return [
      'nombre' => $nombre,
      'apellido' => $apellido,
      'fecha_nacimiento' => $fecha_nacimiento,
      'genero' => $genero,
      'telefono' => $telefono,
      'email' => $email,
      'action'=> $action,
      'currentpassword' => $contraseña_actual,
      'password' => $contraseña_nueva,
      'confirmpassword' => $contraseña_confirmacion
    ];
  }
  public function saveImagePathToDB($rutaImagen) {
      $this->ensureSessionStarted();
      $id_usuario = $_SESSION['usuario']['id'];

      if (!$rutaImagen) {
          throw new Exception("No se proporcionó una ruta de imagen válida.");
      }

      $stmt = $this->conn->prepare("CALL SPUpdateImg(?, ?)");
      $stmt->bind_param("is", $id_usuario, $rutaImagen);

      if (!$stmt->execute()) {
          throw new Exception("Error al guardar la imagen en la base de datos: " . $stmt->error);
      }

      $stmt->close();
  }
  public function uploadFile() {
      if (!isset($_FILES['imagen_usuario'])) {
          return null;
      }

      $archivo = $_FILES['imagen_usuario'];
      if ($archivo['error'] !== UPLOAD_ERR_OK) {
          return null;
      }

      $nombreArchivo = basename($archivo['name']);
      $rutaDestino = "uploads/" . uniqid("img_") . "_" . $nombreArchivo;

      if (move_uploaded_file($archivo['tmp_name'], $rutaDestino)) {
          $this->saveImagePathToDB($rutaDestino);
          return $rutaDestino;
      } else {
          return null;
      }
  }
  public function updateEmail($email){
     $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    if (!$email) {
      throw new Exception("Faltan Email.");
    }
    $stmt = $this->conn->prepare("CALL SPUpdateEmail(?, ?)");
    $stmt->bind_param("si", 
      $email,
      $id_usuario
    );
    if (!$stmt->execute()) {
    throw new Exception("Error al ejecutar: " . $stmt->error);
    }
  }
  public function updatePassword($password) {
    
    $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    if (!$password) {
      throw new Exception("Falta la contraseña.");
    }
    $stmt = $this->conn->prepare("CALL SPUpdatePassword(?, ?)");
    $stmt->bind_param("si", 
      $password,
      $id_usuario
    );
    if (!$stmt->execute()) {
      throw new Exception("Error al ejecutar: " . $stmt->error);
    }
  }
 public function uploadData($nombre, $apellido, $fecha_nacimiento, $genero) {
    $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    if (!$nombre) throw new Exception("Falta el nombre");
    if (!$apellido) throw new Exception("Falta el apellido");
    if (!$fecha_nacimiento) throw new Exception("Falta la fecha de nacimiento");
    if (!$genero) throw new Exception("Falta el género");
    $stmt = $this->conn->prepare("CALL SPUpdateInfo(?, ?, ?, ?, ?)");
    $stmt->bind_param("issss", 
      $id_usuario, 
      $nombre, 
      $apellido, 
      $fecha_nacimiento, 
      $genero
    );
    if (!$stmt->execute()) {
    throw new Exception("Error al ejecutar: " . $stmt->error);
    }
}
public function uploadPhone($telefono){
    if (!$telefono) {
    throw new Exception("Faltan datos requeridos para subir.");
    }
    $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    $stmt = $this->conn->prepare("CALL SPUpdateNumber(?, ?)");
    $stmt->bind_param("is", $id_usuario, $telefono);
    if (!$stmt->execute()) {
    throw new Exception("Error al ejecutar: " . $stmt->error);
    }
}
    public function generateToken() {
        return bin2hex(random_bytes(32));
    }

    public function insertToken($email, $token, $expires) {
      $stmtUser = $this->conn->prepare("SELECT id_usuario FROM usuarios WHERE email = ?");
      $stmtUser->bind_param("s", $email);
      $stmtUser->execute();
      $result = $stmtUser->get_result();
      $row = $result->fetch_assoc();
      $stmtUser->close();

      if (!$row) {
          throw new Exception("No se encontró el usuario con ese email.");
      }
      $id_usuario = $row['id_usuario'];

      $stmt = $this->conn->prepare("CALL SPInsertEmailReset(?, ?, ?)");
      $stmt->bind_param("iss", $id_usuario, $token, $expires);
      $stmt->execute();
      $stmt->close();
    }

    public function getTokenData($token) {
        $stmt = $this->conn->prepare("CALL SPGetEmailResetByToken(?)");
        $stmt->bind_param("s", $token);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        $stmt->close();
        return $data ?: null;
    }
    public function deleteToken($token) {
        $stmt = $this->conn->prepare("DELETE FROM email_resets WHERE token = ?");
        $stmt->bind_param("s", $token);
        $stmt->execute();
        $stmt->close();
    }
public function sendVerifyEmail($email, $token) {
        $mail = new PHPMailer(true);
        try {
            $mail->isSMTP();
            $mail->Host = 'smtp.gmail.com';
            $mail->SMTPAuth = true;
            $mail->Username = $_ENV['EMAIL_USER'];
            $mail->Password = $_ENV['EMAIL_PASS'];
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port = 587;

            $mail->setFrom($_ENV['EMAIL_USER'], 'Soporte TravelAir');
            $mail->addAddress($email);

            $mail->isHTML(true);
            $mail->Subject = 'Email Verification - TravelAir';

            $recoveryLink = "http://localhost/OP/BACK/PHP/verifyEmail.php?token=" . urlencode($token);

            $mail->Body = "
            <div style='font-family: Arial, sans-serif; max-width: 600px; margin: auto; border-radius: 8px; overflow: hidden;'>
                <div style='background-color: #0077cc; height: 50px;'></div>
                <div style='background-color: #ffffff; padding: 40px; text-align: center;'>
                    <h2 style='color: #333;'>Verificacion de Email</h2>
                    <p style='color: #555;'>Hola, recibimos una solicitud para verificar tu Email.</p>
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
}
?>