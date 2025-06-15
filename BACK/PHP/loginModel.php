<?php
class LoginModel{
    private $conn;
    public function __construct($conn){
        $this->conn = $conn;
    }
    public function bringPassword($mail){
    $stmt = $this->conn->prepare("CALL SPBringpassword(?)");
    $stmt->bind_param("s", $mail);
    $stmt->execute();
    $resultado = $stmt->get_result();
    $usuario = $resultado->fetch_assoc(); 
    $stmt->close();
    
    if (!$usuario) {
        return null; 
    }
    return $hashGuardado = $usuario['contraseña']; 
    
    }
    public function verifyPassword($password, $hashGuardado){
        if ($hashGuardado === null) {
        return ["success" => false, "mensaje" => "Usuario no encontrado"];
    }

    if (!password_verify($password, $hashGuardado)) {
        return ["success" => false, "mensaje" => "Contraseña incorrecta"];
    }

    return ["success" => true, "mensaje" => "Inicio de sesión exitoso"];
    }
     public function bringInput(){
                $raw = file_get_contents("php://input");
                $datos = json_decode($raw, true);

                if (!$datos) {
                    echo json_encode(["error" => "No se pudo decodificar JSON"]);
                    exit;
                }

                
                $email = trim($datos['email'] ?? '');
                $password = trim($datos['password'] ?? '');
                

                return [$email, $password];
    }
    public function closeConn(){
        $this->conn->close();
    }
}
/*
$mysqli = new mysqli("localhost", "root", "", "paquetes_viajes");

$datos = json_decode(file_get_contents("php://input"), true);

$mail = $datos['email'] ?? '';
$password = $datos['password'] ?? '';

$stmt = $mysqli->prepare("CALL SPTraerUsuario(?)");
$stmt->bind_param("s", $email);
$stmt->execute();
$resultado = $stmt->get_result();

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(["error" => "Email inválido"]);
    return;
}
if ($resultado && $resultado->num_rows > 0) {
    $usuario = $resultado->fetch_assoc(); 
    $hashGuardado = $usuario['password']; 

    if (!password_verify($password, $hashGuardado)) {
    echo json_encode(["error" => "Contraseña incorrecta"]);
    return;
    } 
    echo json_encode(["mensaje" => "Login correcto"]);
   
} else {
    echo json_encode(["error" => "Usuario no encontrado"]);
}

$stmt->close();
$mysqli->close();
*/
?>