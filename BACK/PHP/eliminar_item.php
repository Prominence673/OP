<?php
header("Content-Type: application/json");
require_once __DIR__ . '/connection.php';

$input = json_decode(file_get_contents("php://input"), true);
$itemId = $input['item_id'] ?? null;

if (!$itemId) {
    echo json_encode(["error" => "Datos incompletos"]);
    exit;
}

try {
    // Verificar que el item existe
    $stmt = $conn->prepare("SELECT id_item FROM carrito_items WHERE id_item = ?");
    $stmt->bind_param("i", $itemId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode(["error" => "Item no encontrado"]);
        exit;
    }
    
    // Eliminar item
    $stmt = $conn->prepare("DELETE FROM carrito_items WHERE id_item = ?");
    $stmt->bind_param("i", $itemId);
    $stmt->execute();
    
    echo json_encode(["success" => true]);
    
} catch (Exception $e) {
    echo json_encode(["error" => "Error en la base de datos: " . $e->getMessage()]);
} finally {
    $conn->close();
}
?>