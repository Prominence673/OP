<?php
session_start();
header('Content-Type: application/json');
require_once 'connection.php';

if (!isset($_SESSION['usuario'])) {
    echo json_encode(['error' => 'No hay sesión activa']);
    exit;
}

$id_usuario = $_SESSION['usuario']['id'] ?? null;
$input = json_decode(file_get_contents('php://input'), true);
$opinion = trim($input['opinion'] ?? '');

if ($opinion === '') {
    echo json_encode(['error' => 'La opinión no puede estar vacía']);
    exit;
}

$stmt = $conn->prepare("INSERT INTO opiniones (id_usuario, opinion) VALUES (?, ?)");
$stmt->bind_param("is", $id_usuario, $opinion);

if ($stmt->execute()) {
    echo json_encode(['mensaje' => 'Opinión enviada correctamente']);
} else {
    echo json_encode(['error' => 'Error al guardar la opinión']);
}
$stmt->close();
$conn->close();