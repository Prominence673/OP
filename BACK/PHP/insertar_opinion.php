<?php
require_once 'connection.php';
header('Content-Type: application/json');
if ($conn->connect_errno) {
    http_response_code(500);
    echo json_encode(["error" => "Error de conexión a la base de datos: " . $mysqli->connect_error]);
    exit;
}
$input = json_decode(file_get_contents('php://input'), true);
$nombre   = trim($input['nombre'] ?? '');
$email    = trim($input['email'] ?? '');
$telefono = trim($input['telefono'] ?? '');
$motivo   = intval($input['motivo'] ?? 0); // <-- CORRECTO
$opinion  = trim($input['opinion'] ?? '');

$stmt = $conn->prepare("INSERT INTO opiniones (Nombre, mail, id_motivo, telefono, opinion) VALUES (?, ?, ?, ?, ?)");
$stmt->bind_param("ssiss",  $nombre, $email, $motivo, $telefono, $opinion );
if ($stmt->execute()) {
    echo json_encode(['mensaje' => 'Gracias por tu mensaje']);
} else {
    echo json_encode(['error' => 'Error al guardar en la base de datos']);
}
$stmt->close();
$conn->close();
?>
