<?php
header('Content-Type: application/json');
require_once 'connection.php';

$tabla = $_GET['tabla'] ?? '';

// Obtener todas las tablas de la base de datos
$tablas = [];
$res = $conn->query("SHOW TABLES");
while ($row = $res->fetch_array()) {
    $tablas[] = $row[0];
}

// Si no se pasa tabla, devolver la lista de tablas
if (!$tabla) {
    echo json_encode($tablas);
    exit;
}

// Validar que la tabla exista
if (!in_array($tabla, $tablas)) {
    echo json_encode(["error" => "Tabla no permitida"]);
    exit;
}

// Consultar los datos de la tabla
$res = $conn->query("SELECT * FROM `$tabla`");
if (!$res) {
    echo json_encode(["error" => $conn->error]);
    exit;
}
$data = [];
while ($row = $res->fetch_assoc()) $data[] = $row;
echo json_encode($data);