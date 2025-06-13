<?php
require_once 'connection.php'; // tu conexión MySQL

header('Content-Type: application/json');

// Recibimos datos JSON del frontend
$data = json_decode(file_get_contents("php://input"), true);

$id_usuario = $data['id_usuario'] ?? null;
$id_paquete = $data['id_paquete'] ?? null;
$cantidad = $data['cantidad'] ?? 1;

if (!$id_usuario || !$id_paquete) {
    echo json_encode(["success" => false, "error" => "Faltan datos"]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL SPAgregarAlCarrito(?, ?, ?)");
    if (!$stmt) {
        throw new Exception("Error en prepare: " . $conn->error);
    }

    $stmt->bind_param("iii", $id_usuario, $id_paquete, $cantidad);

    if (!$stmt->execute()) {
        throw new Exception("Error en execute: " . $stmt->error);
    }

    echo json_encode(["success" => true, "mensaje" => "Item agregado al carrito"]);

    $stmt->close();
    $conn->close();
} catch (Exception $e) {
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
}
