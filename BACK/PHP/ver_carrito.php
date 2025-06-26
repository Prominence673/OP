<?php
session_start();
header('Content-Type: application/json');
include 'connection.php';

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
  CASE ci.tipo
    WHEN 'paquete' THEN p.nombre_viaje
    WHEN 'auto' THEN a.nombre
    WHEN 'estadia' THEN e.nombre
    WHEN 'pasaje' THEN pa.nombre
    ELSE 'Producto'
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
  $items[] = $row;
}
$stmt->close();
echo json_encode(['items' => $items]);