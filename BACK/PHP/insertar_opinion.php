<?php
session_start();
header('Content-Type: application/json');
$host = "localhost";
$user = "root";
$pass = "";
$dbname = "paquetes_viajes";
$mysqli = new mysqli($host, $user, $pass, $dbname);

if ($mysqli->connect_errno) {
    http_response_code(500);
    echo json_encode(["error" => "Error de conexión a la base de datos: " . $mysqli->connect_error]);
    exit;
}

$id_usuario = $_SESSION['usuario']['id'] ?? null;

// Recibir los datos del formulario
$nombre   = trim($_POST['nombre'] ?? '');
$email    = trim($_POST['email'] ?? '');
$telefono = trim($_POST['telefono'] ?? '');
$motivo   = trim($_POST['motivo'] ?? '');
$opinion  = trim($_POST['mensaje'] ?? '');

// Validar campos obligatorios
if ($nombre === '' || $email === '' || $motivo === '' || $opinion === '') {
    echo json_encode(['error' => 'Faltan campos obligatorios']);
    exit;
}

// Mapeo del motivo textual a ID en tipo_opinion
$mapa_tipos = [
    "consulta"   => 1,
    "reclamo"    => 2,
    "sugerencia" => 3,
    "otro"       => 4
];

$id_tipo = $mapa_tipos[$motivo] ?? null;

if (!$id_tipo) {
    echo json_encode(['error' => 'Motivo no válido']);
    exit;
}

// Insertar en la tabla opiniones
$stmt = $conn->prepare("INSERT INTO opiniones (id_usuario, opinion, nombre, email, telefono, id_tipo) VALUES (?, ?, ?, ?, ?, ?)");
$stmt->bind_param("issssi", $id_usuario, $opinion, $nombre, $email, $telefono, $id_tipo);

if ($stmt->execute()) {
    echo json_encode(['mensaje' => 'Gracias por tu mensaje']);
} else {
    echo json_encode(['error' => 'Error al guardar en la base de datos']);
}

$stmt->close();
$conn->close();
