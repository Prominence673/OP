<?php
session_start();
header('Content-Type: application/json');
include 'connection.php';

if (!isset($_SESSION['usuario'])) {
  echo json_encode(['error' => 'No logueado']);
  exit;
}
$id_usuario = $_SESSION['usuario']['id_usuario'];
$data = json_decode(file_get_contents('php://input'), true);

$nombre = $data['nombre'] ?? '';
$apellido = $data['apellido'] ?? '';
$dni = $data['dni'] ?? '';
$metodo_pago = $data['metodo_pago'] ?? '';
$numero_tarjeta = $data['numero_tarjeta'] ?? null;

// Buscar carrito activo
$stmt = $conn->prepare("SELECT id_carrito FROM carrito WHERE id_usuario=? AND estado='activo' ORDER BY fecha_creacion DESC LIMIT 1");
$stmt->bind_param("i", $id_usuario);
$stmt->execute();
$stmt->bind_result($carrito_id);
if (!$stmt->fetch()) {
  echo json_encode(['error' => 'No hay carrito']);
  exit;
}
$stmt->close();

// Traer items del carrito
$stmt = $conn->prepare("SELECT id_item, tipo, id_producto, cantidad FROM carrito_items WHERE id_carrito=?");
$stmt->bind_param("i", $carrito_id);
$stmt->execute();
$res = $stmt->get_result();
$items = [];
while ($row = $res->fetch_assoc()) {
  $items[] = $row;
}
if (!$items) {
  echo json_encode(['error' => 'El carrito está vacío']);
  exit;
}

// Calcular total y obtener precios
$total = 0;
foreach ($items as &$item) {
  $sql = "";
  switch ($item['tipo']) {
    case 'paquete':
      $sql = "SELECT precio_aprox as precio FROM paquetes WHERE id_paquetes=?";
      break;
    case 'auto':
      $sql = "SELECT precio FROM autos WHERE id_autos=?";
      break;
    case 'estadia':
      $sql = "SELECT precio FROM estadias WHERE id_estadias=?";
      break;
    case 'pasaje':
      $sql = "SELECT precio_desde as precio FROM pasajes WHERE id_pasajes=?";
      break;
    default:
      $sql = null;
  }
  if ($sql) {
    $stmt2 = $conn->prepare($sql);
    $stmt2->bind_param("i", $item['id_producto']);
    $stmt2->execute();
    $stmt2->bind_result($precio);
    $stmt2->fetch();
    $stmt2->close();
    $item['precio_unitario'] = $precio;
    $item['subtotal'] = $precio * $item['cantidad'];
    $total += $item['subtotal'];
  }
}

// Descuento si es efectivo
if ($metodo_pago === 'efectivo') {
  $total *= 0.7;
}

// Registrar pedido
$stmt = $conn->prepare("INSERT INTO pedido (id_usuario, total, fecha, nombre, apellido, dni) VALUES (?, ?, NOW(), ?, ?, ?)");
$stmt->bind_param("idsss", $id_usuario, $total, $nombre, $apellido, $dni);
if (!$stmt->execute()) {
  echo json_encode(['error' => 'No se pudo registrar el pedido']);
  exit;
}
$id_pedido = $stmt->insert_id;
$stmt->close();

// Registrar detalle de pedido
$stmt = $conn->prepare("INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, total) VALUES (?, ?, ?, ?, ?)");
foreach ($items as $item) {
  $subtotal = $item['precio_unitario'] * $item['cantidad'];
  $stmt->bind_param("iiidd", $id_pedido, $item['id_producto'], $item['cantidad'], $item['precio_unitario'], $subtotal);
  $stmt->execute();
}
$stmt->close();

// Marcar carrito como comprado y limpiar items
$conn->query("UPDATE carrito SET estado='comprado' WHERE id_carrito=$carrito_id");
$conn->query("DELETE FROM carrito_items WHERE id_carrito=$carrito_id");

echo json_encode(['mensaje' => 'Compra realizada con éxito. Total: $' . number_format($total, 2, ',', '.')]);