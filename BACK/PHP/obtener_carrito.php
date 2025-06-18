<?php
header("Content-Type: application/json");
require_once __DIR__ . '/connection.php';

ini_set('display_errors', 0);
error_reporting(0);

$id_usuario = 2; // ID hardcodeado temporalmente

function sendJsonError($message) {
    echo json_encode(['error' => $message]);
    exit;
}

try {
    if (!$conn) {
        sendJsonError("Error de conexión a la base de datos");
    }

    // 1. Obtener el ID del carrito del usuario
    $stmt = $conn->prepare("SELECT id_carrito FROM carrito WHERE id_usuario = ?");
    if (!$stmt) {
        sendJsonError("Error al preparar la consulta: " . $conn->error);
    }
    
    $stmt->bind_param("i", $id_usuario);
    if (!$stmt->execute()) {
        sendJsonError("Error al ejecutar la consulta: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode(["items" => []]);
        exit;
    }
    
    $carrito = $result->fetch_assoc();
    $id_carrito = $carrito['id_carrito'];
    
    // 2. Obtener los items del carrito con información de los paquetes
    // USANDO LOS NOMBRES EXACTOS DE COLUMNAS DE TU ESTRUCTURA
    $stmt = $conn->prepare("
        SELECT 
            ci.id_item as id_carrito_item,
            ci.id_paquete,
            ci.cantidad,
            p.nombre_paquete as nombre,
            p.precio as precio
        FROM carrito_items ci
        JOIN paquetes p ON ci.id_paquete = p.id_paquete
        WHERE ci.id_carrito = ?
    ");
    
    if (!$stmt) {
        sendJsonError("Error al preparar la consulta: " . $conn->error);
    }
    
    $stmt->bind_param("i", $id_carrito);
    if (!$stmt->execute()) {
        sendJsonError("Error al ejecutar la consulta: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    
    $items = [];
    while ($row = $result->fetch_assoc()) {
        $items[] = [
            'id' => $row['id_carrito_item'],
            'paquete_id' => $row['id_paquete'],
            'nombre' => $row['nombre'],
            'precio' => $row['precio'],
            'cantidad' => $row['cantidad'],
            'subtotal' => $row['precio'] * $row['cantidad'],
            'fecha_agregado' => $row['fecha_agregado'] // Agregado si lo necesitas
        ];
    }
    
    echo json_encode(["items" => $items]);
    
} catch (Exception $e) {
    sendJsonError("Error interno del servidor: " . $e->getMessage());
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>