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
    public function bringUser($mail){
        $stmt = $this->conn->prepare("CALL SPbrinUser(?)");
        $stmt->bind_param("s", $mail);
        $stmt->execute();
        $resultado = $stmt->get_result();
        $user = $resultado->fetch_assoc(); 
        $stmt->close();
        if (!$user) {
            return null;
        }
        return [
        'id' => $user['id_usuario'],
        'nombre' => $user['usuario_nombre']
        ];
    }
        public function bringInput() {
        $raw = file_get_contents("php://input");
        $datos = json_decode($raw, true);

        if (!is_array($datos)) {
            return [null, null, null];
        }

        $email = trim($datos['email'] ?? '');
        $password = trim($datos['password'] ?? '');
        $rememberme = $datos['rememberme'] ?? false;

        return [$email, $password, $rememberme];
    }
    public function closeConn(){
        $this->conn->close();
    }
}
?>