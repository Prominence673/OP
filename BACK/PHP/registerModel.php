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
         try {
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return ["success" => false, "error" => "Email inválido"];
            }
        return ["success" => true];
         } catch (mysqli_sql_exception $e) {
            if ($e->getCode() === 1062) {
                
            return ["success" => false, "error" => "El email ya está en uso"];
            }
          
            return ["success" => false, "error" => "Excepción: " . $e->getMessage()];
        }
        }
    public function verifyInput($user , $email, $password, $confirm){
             if ($user === '' || $email === '' || $password === '' || $confirm === '') {
                return ["success" => false, "error" => "Completar todos los campos"];
            }

            if ($password !== $confirm) {
                return ["success" => false, "error" => "Las contraseñas no coinciden"];
            }

            return ["success" => true];
            
    }
    function validarPasswordFuerte(string $password): array {
            $errores = [];

            if (strlen($password) < 8) {
                $errores[] = "La contraseña debe tener al menos 8 caracteres.";
            }
            if (!preg_match('/[a-z]/', $password)) {
                $errores[] = "Debe contener al menos una letra minúscula.";
            }
            if (!preg_match('/[A-Z]/', $password)) {
                $errores[] = "Debe contener al menos una letra mayúscula.";
            }
            if (!preg_match('/\d/', $password)) {
                $errores[] = "Debe contener al menos un número.";
            }
            if (!preg_match('/[@#$^&+=.!?\-_*]/', $password)) {
                $errores[] = "Debe contener al menos un carácter especial (@ # $ ^ & + = . ! ? - _ *).";
            }

            if (!empty($errores)) {
                return ["valido" => false, "errores" => $errores];
            }

            return ["valido" => true];
        }
    public function bringInput(){
                $raw = file_get_contents("php://input");
                $datos = json_decode($raw, true);

                if (!$datos) {
                    echo json_encode(["error" => "No se pudo decodificar JSON"]);
                    exit;
                }

                $user = trim($datos['user'] ?? '');
                $email = trim($datos['email'] ?? '');
                $password = trim($datos['password'] ?? '');
                $confirm = trim($datos['confirm'] ?? '');

                return [$user, $email, $password, $confirm];
            }
    public function registerUser($user, $email, $hash_password){
         try {
            $stmt = $this->conn->prepare("CALL SPRegistrarUsuario(?, ?, ?, ?)");
            if (!$stmt) {
                throw new Exception("Error al preparar la consulta: " . $this->conn->error);
            }
            $id_rol = 2;
            $stmt->bind_param("sssi", $user, $email, $hash_password, $id_rol);
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