<?php
$mysqli = new mysqli(hostname: "localhost", username: "root", password: "", database: "paquetes_viajes");

$datos = json_decode(json: file_get_contents(filename: "php://input"), associative: true);

$name = trim(string: $datos['name'] ?? '');
$email = trim(string: $datos['email'] ?? '');
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
?>