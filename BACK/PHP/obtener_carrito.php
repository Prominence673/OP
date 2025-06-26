<?php
session_start();
header('Content-Type: application/json');
require_once 'connection.php';

if (!isset($_SESSION['usuario'])) {
    echo json_encode(['items' => []]);
    exit;
}
$id_usuario = $_SESSION['usuario']['id'];

// Buscar carrito activo
$stmt = $conn->prepare("SELECT id_carrito FROM carrito WHERE id_usuario=? AND estado='activo' ORDER BY fecha_creacion DESC LIMIT 1");
$stmt->bind_param("i", $id_usuario);
$stmt->execute();
$stmt->bind_result($carrito_id);
if (!$stmt->fetch()) {
    echo json_encode(['items' => []]);
    exit;
}
$stmt->close();

// Traer items del carrito
$sql = "SELECT ci.id_item, ci.tipo, ci.id_producto, ci.cantidad,
    COALESCE(p.nombre_viaje, a.nombre, e.nombre, pa.nombre, 'Producto') AS nombre,
    COALESCE(p.precio_aprox, a.precio, e.precio, pa.precio_desde, 0) AS precio
    FROM carrito_items ci
    LEFT JOIN productos prod ON ci.id_producto = prod.id_producto
    LEFT JOIN paquetes p ON ci.tipo='paquete' AND prod.id_referencia=p.id_paquetes
    LEFT JOIN autos a ON ci.tipo='auto' AND prod.id_referencia=a.id_autos
    LEFT JOIN estadias e ON ci.tipo='estadia' AND prod.id_referencia=e.id_estadias
    LEFT JOIN pasajes pa ON ci.tipo='pasaje' AND prod.id_referencia=pa.id_pasajes
    WHERE ci.id_carrito = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $carrito_id);
$stmt->execute();
$res = $stmt->get_result();
$items = [];
while ($row = $res->fetch_assoc()) {
    $items[] = [
        'id_item' => $row['id_item'],
        'tipo' => $row['tipo'],
        'id_producto' => $row['id_producto'],
        'cantidad' => $row['cantidad'],
        'nombre' => $row['nombre'],
        'precio' => $row['precio']
    ];
}
$stmt->close();
echo json_encode(['items' => $items]);
?>