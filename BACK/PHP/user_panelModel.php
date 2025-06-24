<?php
class userPanel {
  private $conn;

  public function __construct($conn) {
    $this->conn = $conn;
  }

  public function bringInputFromForm() {
    $nombre = trim($_POST['name'] ?? '');
    $apellido = trim($_POST['surname'] ?? '');
    $dia = $_POST['dia'] ?? '';
    $mes = $_POST['mes'] ?? '';
    $anio = $_POST['anio'] ?? '';
    $genero = $_POST['genero'] ?? '';
    $telefono = trim($_POST['telefono'] ?? '');
    $email = trim($_POST['email'] ?? '');
    $currentpassword = trim($_POST['currentpassword'] ?? '');
    $password = trim($_POST['password'] ?? '');
    $confirmpassword = trim($_POST['confirmpassword'] ?? '');
    $action = trim($_POST['actions'] ?? '');

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
      'currentpassword' => $currentpassword,
      'password' => $password,
      'confirmpassword' => $confirmpassword,
      'action' => $action
    ];
  }

  public function uploadFile() {
    if (!isset($_FILES['fotoPerfil'])) {
      return null;
    }

    $archivo = $_FILES['fotoPerfil'];
    if ($archivo['error'] !== UPLOAD_ERR_OK) {
      return null;
    }

    $nombreArchivo = basename($archivo['name']);
    $rutaDestino = "uploads/" . uniqid("img_") . "_" . $nombreArchivo;

    if (move_uploaded_file($archivo['tmp_name'], $rutaDestino)) {
      return $rutaDestino;
    } else {
      return null;
    }
  }

 public function uploadData($nombre, $apellido, $fecha_nacimiento, $genero) {
    session_start();
    $id_usuario = $_SESSION['usuario']['id'];

    $stmt = $this->conn->prepare("CALL SPInsertarDatosPersonales(?, ?, ?, ?, ?)");
    $stmt->bind_param("issss", 
      $id_usuario, 
      $nombre, 
      $apellido, 
      $fecha_nacimiento, 
      $genero
    );
    $stmt->execute();
}
public function uploadPhone($telefono){
    session_start();
    $id_usuario = $_SESSION['usuario']['id'];
    $stmt = $this->conn->prepare("CALL SPInsertarTelefono(?, ?)");
    $stmt->bind_param("is", $id_usuario, $telefono);
    $stmt->execute();
}
    public function updateEmail($nuevoEmail) {
        session_start();
        $id_usuario = $_SESSION['usuario']['id'];
        $stmt = $this->conn->prepare("CALL SPActualizarEmail(?, ?)");
        $stmt->bind_param("is", $id_usuario, $nuevoEmail);
        $stmt->execute();
    }

    public function updatePassword($nuevoHash) {
        session_start();
        $id_usuario = $_SESSION['usuario']['id'];
        $stmt = $this->conn->prepare("CALL SPCambiarPassword(?, ?)");
        $stmt->bind_param("is", $id_usuario, $nuevoHash);
        $stmt->execute();
    }
    public function generateToken($length = 32) {
        return bin2hex(random_bytes($length));
    }

    public function insertToken($email, $token, $expires) {
        $stmt = $this->conn->prepare("CALL SPInsertarTokenVerificacion(?, ?, ?)");
        $stmt->bind_param("sss", $email, $token, $expires);
        $stmt->execute();
    }

    public function sendVerifyEmail($email, $token) {
        $verificationLink = "https://tusitio.com/verificar.php?token=" . urlencode($token);
        $subject = "Verifica tu correo electrónico";
        $message = "Haz clic en el siguiente enlace para verificar tu correo: $verificationLink";
        $headers = "From: no-reply@tusitio.com\r\nContent-Type: text/plain; charset=UTF-8";

        if (mail($email, $subject, $message, $headers)) {
            return ["success" => true, "mensaje" => "Correo de verificación enviado"];
        } else {
            return ["success" => false, "error" => "No se pudo enviar el correo de verificación"];
        }
    }
    public function closeConn() {
        $this->conn->close();
    }
}
?>