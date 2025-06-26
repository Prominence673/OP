<?php
file_put_contents('debug_carrito.log', print_r($_POST, true), FILE_APPEND);
session_start();
header('Content-Type: application/json');
require_once 'connection.php';

if (!isset($_SESSION['usuario'])) {
    echo json_encode(['error' => 'No logueado']);
    exit;
}
$id_usuario = $_SESSION['usuario']['id'];
$tipo = $_POST['tipo'] ?? '';
$cantidad = max(1, intval($_POST['cantidad'] ?? 1));

switch ($tipo) {
    case 'paquete':
        $id_referencia = $_POST['id_paquete'] ?? null;
        break;
    case 'auto':
        $id_referencia = $_POST['id_auto'] ?? $_POST['id_autos'] ?? null;
        break;
    case 'estadia':
        $id_referencia = $_POST['id_estadia'] ?? $_POST['id_estadias'] ?? null;
        break;
    case 'pasaje':
        $id_referencia = $_POST['id_pasaje'] ?? $_POST['id_pasajes'] ?? null;
        break;
    default:
        $id_referencia = null;
}

if (!$id_referencia || !$tipo) {
    echo json_encode(['error' => 'Datos incompletos']);
    exit;
}


$carrito_id = null;
$stmt = $conn->prepare("SELECT id_carrito FROM carrito WHERE id_usuario=? AND estado='activo' ORDER BY fecha_creacion DESC LIMIT 1");
$stmt->bind_param("i", $id_usuario);
$stmt->execute();
$stmt->bind_result($carrito_id);
if (!$stmt->fetch()) {
    $stmt->close();
    $stmt = $conn->prepare("INSERT INTO carrito (id_usuario, estado) VALUES (?, 'activo')");
    $stmt->bind_param("i", $id_usuario);
    $stmt->execute();
    $carrito_id = $stmt->insert_id;
}
$stmt->close();

$id_producto_pivot = null;
$stmt = $conn->prepare("SELECT id_producto FROM productos WHERE tipo=? AND id_referencia=?");
$stmt->bind_param("si", $tipo, $id_referencia);
$stmt->execute();
$stmt->bind_result($id_producto_pivot);
if (!$stmt->fetch()) {
    $stmt->close();
  
    $stmt = $conn->prepare("INSERT INTO productos (tipo, id_referencia) VALUES (?, ?)");
    $stmt->bind_param("si", $tipo, $id_referencia);
    $stmt->execute();
    $id_producto_pivot = $stmt->insert_id;
}
$stmt->close();


$stmt = $conn->prepare("SELECT id_item, cantidad FROM carrito_items WHERE id_carrito=? AND id_producto=?");
$stmt->bind_param("ii", $carrito_id, $id_producto_pivot);
$stmt->execute();
$stmt->bind_result($id_item, $cant_existente);
if ($stmt->fetch()) {
    $stmt->close();
    $nueva_cant = $cant_existente + $cantidad;
    $stmt = $conn->prepare("UPDATE carrito_items SET cantidad=? WHERE id_item=?");
    $stmt->bind_param("ii", $nueva_cant, $id_item);
    $stmt->execute();
    $stmt->close();
    echo json_encode(['mensaje' => 'Cantidad actualizada en el carrito']);
    exit;
}
$stmt->close();


$stmt = $conn->prepare("INSERT INTO carrito_items (id_carrito, tipo, id_producto, cantidad) VALUES (?, ?, ?, ?)");
$stmt->bind_param("isii", $carrito_id, $tipo, $id_producto_pivot, $cantidad);
if ($stmt->execute()) {
    echo json_encode(['mensaje' => 'Producto agregado al carrito']);
} else {
    echo json_encode(['error' => 'No se pudo agregar al carrito']);
}
$stmt->close();
?>