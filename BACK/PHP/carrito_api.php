<?php
session_start();
header('Content-Type: application/json');
include 'connection.php';

if (!isset($_SESSION['usuario'])) {
  echo json_encode(['error' => 'No logueado']);
  exit;
}
$id_usuario = $_SESSION['usuario']['id_usuario'];
$tipo = $_POST['tipo'] ?? '';
$id = $_POST["id_{$tipo}"] ?? null;
$cantidad = $_POST['cantidad'] ?? 1;

if (!$id || !$tipo) {
  echo json_encode(['error' => 'Datos incompletos']);
  exit;
}

// Ejemplo para paquetes, adaptá para otros tipos si tu carrito lo requiere
if ($tipo === 'paquete') {
  // Lógica para agregar al carrito (usá tu tabla carrito/carrito_items)
  // ...
  echo json_encode(['mensaje' => 'Paquete agregado al carrito']);
  exit;
}
// Repetí para auto, estadia, pasaje...
echo json_encode(['error' => 'Tipo no soportado']);