<?php
session_start();
header('Content-Type: application/json');

// Conexión a la base de datos
$mysqli = new mysqli("localhost", "root", "", "paquetes_viajes");
if ($mysqli->connect_errno) {
    http_response_code(500);
    echo json_encode(["error" => "Error de conexión a la base de datos"]);
    exit;
}

// Obtener datos JSON
$input = json_decode(file_get_contents('php://input'), true);

$nombre = trim($input["nombre"] ?? "");
$email = trim($input["email"] ?? "");
$motivo = trim($input["motivo"] ?? "");
$telefono = trim($input["telefono"] ?? "");
$mensaje = trim($input["opinion"] ?? "");

// Validación básica
if (!$nombre || !$email || !$motivo || !$mensaje) {
    http_response_code(400);
    echo json_encode(["error" => "Faltan campos obligatorios"]);
    exit;
}

// Insertar en la tabla opiniones
$stmt = $mysqli->prepare("INSERT INTO opiniones (nombre, email, motivo, telefono, mensaje, fecha) VALUES (?, ?, ?, ?, ?, NOW())");
if (!$stmt) {
    http_response_code(500);
    echo json_encode(["error" => "Error en la preparación de la consulta"]);
    exit;
}
$stmt->bind_param("sssss", $nombre, $email, $motivo, $telefono, $mensaje);

if ($stmt->execute()) {
    echo json_encode(["mensaje" => "¡Gracias por tu opinión!"]);
} else {
    http_response_code(500);
    echo json_encode(["error" => "No se pudo guardar la opinión"]);
}
$stmt->close();
$mysqli->close();