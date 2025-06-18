<?php
header("Content-Type: application/json");
require_once __DIR__ . '/connection.php';

$input = json_decode(file_get_contents("php://input"), true);
$itemId = $input['item_id'] ?? null;
$operacion = $input['operacion'] ?? null;

if (!$itemId || !$operacion) {
    echo json_encode(["error" => "Datos incompletos"]);
    exit;
}

try {
    // Obtener cantidad actual usando id_item
    $stmt = $conn->prepare("SELECT cantidad FROM carrito_items WHERE id_item = ?");
    $stmt->bind_param("i", $itemId);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode(["error" => "Item no encontrado"]);
        exit;
    }
    
    $item = $result->fetch_assoc();
    $nuevaCantidad = $operacion === "sumar" ? $item['cantidad'] + 1 : max(1, $item['cantidad'] - 1);
    
    // Actualizar cantidad usando id_item
    $stmt = $conn->prepare("UPDATE carrito_items SET cantidad = ? WHERE id_item = ?");
    $stmt->bind_param("ii", $nuevaCantidad, $itemId);
    $stmt->execute();
    
    echo json_encode(["success" => true]);
    
} catch (Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
} finally {
    $conn->close();
}
?>