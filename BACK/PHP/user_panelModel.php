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
    $dni = $datos['dni'] ?? '';
    $genero = $datos['genero'] ?? '';
    $telefono = trim($datos['telefono'] ?? '');
    $email = trim($datos['email'] ?? '');
    $action = $datos['action'] ?? '';
    $contraseña_actual = trim($datos['currentpassword'] ?? '');
    $contraseña_nueva = trim($datos['password'] ?? '');
    $contraseña_confirmacion = trim($datos['confirmpassword'] ?? '');
    $provincia = $datos['provincia'] ?? '';
    $localidad = $datos['localidad'] ?? '';
    $partido = $datos['partido'] ?? '';
    $codigo_postal  = $datos["codigo_postal"] ?? '';

    $fecha_nacimiento = '';
    if ($dia && $mes && $anio) {
      $fecha_nacimiento = "$anio-$mes-$dia";
    }

    return [
      'nombre' => $nombre,
      'apellido' => $apellido,
      'fecha_nacimiento' => $fecha_nacimiento,
      'dni'=> $dni,
      'genero' => $genero,
      'telefono' => $telefono,
      'email' => $email,
      'action'=> $action,
      'currentpassword' => $contraseña_actual,
      'password' => $contraseña_nueva,
      'confirmpassword' => $contraseña_confirmacion,
      'provincia' => $provincia,
      'localidad' => $localidad,
      'partido' => $partido,
      'codigo_postal' => $codigo_postal
    ];
  }
  public function updateEmail($email){
     $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    if ($id_usuario) {
      throw new Exception("No se inicio sesión.");
    } 
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
 public function uploadData($nombre, $apellido, $fecha_nacimiento, $genero, $dni, $provincia, $localidad, $partido, $codigo_postal) {
    $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];

    $stmt = $this->conn->prepare(
        "UPDATE datos_personales 
         SET nombre=?, apellido=?, fecha_nacimiento=?, sexo=?, dni=?, id_provincia=?, id_localidad=?, id_partido=?, codigo_postal=?
         WHERE id_usuario=?"
    );
    $stmt->bind_param(
        "sssssiisii",
        $nombre,
        $apellido,
        $fecha_nacimiento,
        $genero,
        $dni,
        $provincia,  
        $localidad,  
        $partido,    
        $codigo_postal,
        $id_usuario
    );
    if (!$stmt->execute()) {
        throw new Exception("Error al ejecutar: " . $stmt->error);
    }
    $stmt->close();
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
    public function setUsuarioVerificado($id_usuario, $exito) {
        $stmt = $this->conn->prepare("CALL SPSetUsuarioVerificado(?, ?)");
        $stmt->bind_param("ii", $id_usuario, $exito);
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

            $mail->setFrom($_ENV['EMAIL_USER'], 'Soporte KAPIFLY');
            $mail->addAddress($email);

            $mail->isHTML(true);
            $mail->Subject = 'Verificacion Email - KAPIFLY';

            $recoveryLink = "http://localhost/OP/BACK/PHP/verifyRegisterEmail.php?token=" . urlencode($token);

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
public function insertEmailResetToken($nuevo_email, $token, $expires) {
    $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    $this->conn->query("DELETE FROM email_resets WHERE id_usuario = $id_usuario");
    $stmt = $this->conn->prepare("INSERT INTO email_resets (id_usuario, nuevo_email, token, expires_at, creado_en) VALUES (?, ?, ?, ?, NOW())");
    $stmt->bind_param("isss", $id_usuario, $nuevo_email, $token, $expires);
    $stmt->execute();
    $stmt->close();
}
public function getDatosPersonales() {
    $this->ensureSessionStarted();
    $id_usuario = $_SESSION['usuario']['id'];
    $stmt = $this->conn->prepare("SELECT nombre, apellido, fecha_nacimiento, sexo, telefono, dni, id_provincia, id_localidad, id_partido, codigo_postal FROM datos_personales WHERE id_usuario = ?");
    $stmt->bind_param("i", $id_usuario);
    $stmt->execute();
    $res = $stmt->get_result();
    $data = $res->fetch_assoc();
    $stmt->close();
    return $data ?: [];
}
}
?>