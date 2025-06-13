<?php
class registerModel{
    private $conn;
    public function __construct($conn){
        $this->conn = $conn;
    }
    public function hashPassword($password){
        return password_hash($password, PASSWORD_DEFAULT);
    }
    public function verifyMail($mail){
            if (!filter_var($mail, FILTER_VALIDATE_EMAIL)) {
            echo json_encode(["error" => "Email inválido"]);
            return ["success" => false, "error" => "Email inválido"];
            }
        return ["success" => true];
        }
    public function verifyInput($name , $mail, $password, $confirm){
            if (!$name || !$mail || !$password || !$confirm && $password == $confirm) {
                return ["succes" => false, "error" => "Completar todos los campos"];
            }
            return ["success"=> true];
    }
    public function bringInput(){
            $datos = json_decode(json: file_get_contents(filename: "php://input"), associative: true);

            $name = trim($datos['name'] ?? '');
            $mail = trim($datos['email'] ?? '');
            $password = trim($datos['password'] ?? '');
            $confirm = trim($datos['confirm'] ?? '');
            return [$name, $mail, $password, $confirm];
            }
    public function registerUser($name, $mail, $hash_password){
         try {
            $stmt = $this->conn->prepare("CALL SPRegistrarUsuario(?, ?, ?)");
            if (!$stmt) {
                throw new Exception("Error al preparar la consulta: " . $this->conn->error);
            }

            $stmt->bind_param("sss", $name, $mail, $hash_password);
            $stmt->execute();

            if ($stmt->affected_rows > 0) {
                echo json_encode(["mensaje" => "Registro correcto"]);
            } else {
                echo json_encode(["error" => "Error en el registro"]);
            }

            $stmt->close();
            $this->conn->close();

        } catch (Exception $e) {
            echo json_encode(["error" => "Excepción: " . $e->getMessage()]);
        }
    }
}


/*
$mysqli = new mysqli(hostname: "localhost", username: "root", password: "", database: "paquetes_viajes");

$datos = json_decode(json: file_get_contents(filename: "php://input"), associative: true);

$name = trim(string: $datos['name'] ?? '');
$mail = trim(string: $datos['email'] ?? '');
$password = trim(string: $datos['password'] ?? '');
$confirm = trim(string: $datos['confirm'] ?? '');

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(["error" => "Email inválido"]);
    return;
}
if (!$name || !$email || !$password || !$confirm && $password == $confirm) {
    echo json_encode(["error" => "Completar todos los campos"]);
    exit;
}
$hashPassword = password_hash($password, PASSWORD_DEFAULT);
$stmt = $mysqli->prepare("CALL SPRegistrarUsuario(?, ?, ?)");
$stmt->bind_param("sss", $name, $email, $hashPassword);
$stmt->execute();
if ($stmt->affected_rows > 0) {
    echo json_encode(["mensaje" => "Registro correcto"]);
} else {
    echo json_encode(["error" => "Error en el registro"]);
}
$stmt->close();
$mysqli->close();
*/
?>