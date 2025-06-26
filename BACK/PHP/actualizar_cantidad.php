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

    $stmt = $conn->prepare("SELECT cantidad FROM carrito_items WHERE id_item = ?");
    $stmt->bind_param("i", $itemId);
    $stmt->execute();
    $stmt->bind_result($cantidad_actual);
    if (!$stmt->fetch()) {
        echo json_encode(["error" => "Item no encontrado"]);
        $stmt->close();
        exit;
    }
    $stmt->close();


    if ($operacion === "sumar") {
        $nuevaCantidad = $cantidad_actual + 1;
    } elseif ($operacion === "restar") {
        $nuevaCantidad = max(1, $cantidad_actual - 1);
    } else {
        echo json_encode(["error" => "Operación inválida"]);
        exit;
    }


    $stmt = $conn->prepare("UPDATE carrito_items SET cantidad = ? WHERE id_item = ?");
    $stmt->bind_param("ii", $nuevaCantidad, $itemId);
    $stmt->execute();
    $stmt->close();

    echo json_encode(["success" => true, "nuevaCantidad" => $nuevaCantidad]);

} catch (Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
} finally {
    $conn->close();
}
?>