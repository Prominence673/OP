<?php
require_once 'connection.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents("php://input"), true);
$id_usuario = $data['id_usuario'] ?? null;

if (!$id_usuario) {
    echo json_encode(["success" => false, "error" => "Falta el ID del usuario"]);
    exit;
}

try {
    // Obtener el ID del carrito del usuario
    $stmt = $conn->prepare("SELECT id_carrito FROM carrito WHERE id_usuario = ? ORDER BY creado_en DESC LIMIT 1");
    $stmt->bind_param("i", $id_usuario);
    $stmt->execute();
    $stmt->bind_result($id_carrito);
    $stmt->fetch();
    $stmt->close();

    if (!$id_carrito) {
        echo json_encode(["success" => false, "error" => "No se encontró un carrito para este usuario"]);
        exit;
    }

    // Eliminar los ítems del carrito
    $stmt = $conn->prepare("DELETE FROM carrito_items WHERE id_carrito = ?");
    $stmt->bind_param("i", $id_carrito);
    $stmt->execute();

    echo json_encode(["success" => true, "mensaje" => "Carrito vaciado correctamente"]);

    $stmt->close();
    $conn->close();
} catch (Exception $e) {
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
}
