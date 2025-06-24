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

}
?>