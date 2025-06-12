<?php
$mysqli = new mysqli("localhost", "root", "", "paquetes_viajes");

$datos = json_decode(file_get_contents("php://input"), true);

$email = $datos['email'] ?? '';
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
?>