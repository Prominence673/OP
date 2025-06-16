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
?>