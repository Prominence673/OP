<?php
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');
ini_set('display_errors', 0);
error_log("Test de error_log funcionando");
error_reporting(E_ALL);
error_reporting(E_ALL);
header("Content-Type: application/json");
require_once __DIR__ . '/connection.php';
ini_set('display_errors', 0);
error_reporting(0);
session_start();
$id_usuario = $_SESSION["usuario"]["id"];

function sendJsonError($message) {
    echo json_encode(['error' => $message]);
    exit;
}

try {
    if (!$conn) {
        sendJsonError("Error de conexión a la base de datos");
    }

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
    error_log('Carrito obtenido: ' . print_r($carrito, true));
    $id_carrito = $carrito['id_carrito'];

    $stmt = $conn->prepare("
        SELECT ci.id_item, ci.tipo, ci.id_producto, ci.cantidad,
        CASE ci.tipo
            WHEN 'paquete' THEN p.nombre_viaje
            WHEN 'auto' THEN a.nombre
            WHEN 'estadia' THEN e.nombre
            WHEN 'pasaje' THEN pa.nombre
            ELSE 'Producto desconocido'
        END AS nombre,
        CASE ci.tipo
            WHEN 'paquete' THEN p.precio_aprox
            WHEN 'auto' THEN a.precio
            WHEN 'estadia' THEN e.precio
            WHEN 'pasaje' THEN pa.precio_desde
            ELSE 0
        END AS precio
        FROM carrito_items ci
        LEFT JOIN productos prod ON ci.id_producto = prod.id_producto
        LEFT JOIN paquetes p ON ci.tipo='paquete' AND prod.id_referencia = p.id_paquetes
        LEFT JOIN autos a ON ci.tipo='auto' AND prod.id_referencia = a.id_autos
        LEFT JOIN estadias e ON ci.tipo='estadia' AND prod.id_referencia = e.id_estadias
        LEFT JOIN pasajes pa ON ci.tipo='pasaje' AND prod.id_referencia = pa.id_pasajes
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
    $rows = $result->fetch_all(MYSQLI_ASSOC);
        error_log('Resultado carrito_items: ' . print_r($rows, true));

        $items = [];
        foreach ($rows as $row) {
            $items[] = [
                'id' => $row['id_item'],
                'paquete_id' => $row['id_producto'],
                'nombre' => $row['nombre'],
                'precio' => $row['precio'],
                'cantidad' => $row['cantidad'],
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