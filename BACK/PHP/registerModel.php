<?php
class registerModel{
    private $conn;
    public function __construct($conn){
        $this->conn = $conn;
        mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    }
    public function hashPassword($password){
        return password_hash($password, PASSWORD_DEFAULT);
    }
    public function verifyMail($email){
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return ["success" => false, "error" => "Email inválido"];
            }
        return ["success" => true];
        }
    public function verifyInput($name , $email, $password, $confirm){
             if ($name === '' || $email === '' || $password === '' || $confirm === '') {
                return ["success" => false, "error" => "Completar todos los campos"];
            }

            if ($password !== $confirm) {
                return ["success" => false, "error" => "Las contraseñas no coinciden"];
            }

            return ["success" => true];
    }
    public function bringInput(){
                $raw = file_get_contents("php://input");
                $datos = json_decode($raw, true);

                if (!$datos) {
                    echo json_encode(["error" => "No se pudo decodificar JSON"]);
                    exit;
                }

                $name = trim($datos['name'] ?? '');
                $email = trim($datos['email'] ?? '');
                $password = trim($datos['password'] ?? '');
                $confirm = trim($datos['confirm'] ?? '');

                return [$name, $email, $password, $confirm];
            }
    public function registerUser($name, $email, $hash_password){
         try {
            $stmt = $this->conn->prepare("CALL SPRegistrarUsuario(?, ?, ?)");
            if (!$stmt) {
                throw new Exception("Error al preparar la consulta: " . $this->conn->error);
            }
            $stmt->bind_param("sss", $name, $email, $hash_password);
            $stmt->execute();
            if ($stmt->affected_rows > 0) {
                return ["success" => true];
            } else {
                return ["success" => false, "error" => "Error en el registro"];
            }
         } catch (mysqli_sql_exception $e) {
            if ($e->getCode() === 1062) {
                
                return ["success" => false, "error" => "El email ya está en uso"];
            }
          
            return ["success" => false, "error" => "Excepción: " . $e->getMessage()];
        }
    }
    public function closeConn(){
        $this->conn->close();
    }
}
?>