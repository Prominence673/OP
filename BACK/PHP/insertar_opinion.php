<?php
session_start();
header('Content-Type: application/json');
$host = "localhost";
$user = "root";
$pass = "";
$dbname = "paquetes_viajes";
$mysqli = new mysqli($host, $user, $pass, $dbname);

if ($mysqli->connect_errno) {
    http_response_code(500);
    echo json_encode(["error" => "Error de conexión a la base de datos: " . $mysqli->connect_error]);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

$nombre = trim($input["nombre"] ?? "");
$email = trim($input["email"] ?? "");
$id_motivo = intval($input["motivo"] ?? 0);
$telefono = trim($input["telefono"] ?? "");
$mensaje = trim($input["opinion"] ?? "");

if (!$nombre || !$email || !$id_motivo || !$mensaje) {
    http_response_code(400);
    echo json_encode(["error" => "Faltan campos obligatorios"]);
    exit;
}

$stmt = $mysqli->prepare("INSERT INTO opiniones (Nombre, mail, id_motivo, telefono, opinion, fecha) VALUES (?, ?, ?, ?, ?, NOW())");
if (!$stmt) {
    http_response_code(500);
    echo json_encode(["error" => "Error en la preparación de la consulta: " . $mysqli->error]);
    exit;
}
$stmt->bind_param("ssiss", $nombre, $email, $id_motivo, $telefono, $mensaje);

if ($stmt->execute()) {
    echo json_encode(["mensaje" => "¡Gracias por tu opinión!"]);
} else {
    http_response_code(500);
    echo json_encode(["error" => "No se pudo guardar la opinión: " . $stmt->error]);
}
$stmt->close();
$mysqli->close();
