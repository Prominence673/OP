<?php
header('Content-Type: application/json');
require_once 'connection.php';

$tabla = $_GET['tabla'] ?? '';
$permitidas = [
    "usuarios",
    "opiniones",
    "detalle_pedido",
    "pedido",
    "estado_pedido",
    "datos_personales",
    "localidad",
    "provincia",
    "partido"
];

if (!in_array($tabla, $permitidas)) {
    echo json_encode(["error" => "Tabla no permitida"]);
    exit;
}

$res = $conn->query("SELECT * FROM $tabla");
if (!$res) {
    echo json_encode(["error" => $conn->error]);
    exit;
}
$data = [];
while ($row = $res->fetch_assoc()) $data[] = $row;
echo json_encode($data);