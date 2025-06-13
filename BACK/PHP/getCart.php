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
    $stmt = $conn->prepare("
        SELECT ci.id_item, p.nombre_paquete, p.precio, ci.cantidad
        FROM carrito_items ci
        JOIN carrito c ON ci.id_carrito = c.id_carrito
        JOIN paquetes p ON ci.id_paquete = p.id_paquete
        WHERE c.id_usuario = ?
        ORDER BY ci.id_item DESC
    ");

    $stmt->bind_param("i", $id_usuario);
    $stmt->execute();

    $result = $stmt->get_result();
    $items = [];

    while ($row = $result->fetch_assoc()) {
        $items[] = $row;
    }

    echo json_encode(["success" => true, "carrito" => $items]);

    $stmt->close();
    $conn->close();
} catch (Exception $e) {
    echo json_encode(["success" => false, "error" => $e->getMessage()]);
}
