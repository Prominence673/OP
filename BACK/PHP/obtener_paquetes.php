<?php
// filepath: c:\xampp\htdocs\OP\BACK\PHP\obtener_paquetes.php
header('Content-Type: application/json');
include 'conexion.php'; // tu archivo de conexión

$tipo = isset($_GET['tipo']) ? $_GET['tipo'] : '';

$sql = "SELECT * FROM paquetes";
if ($tipo) {
    $sql .= " WHERE tipo_paquete = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $tipo);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    $result = $conn->query($sql);
}

$paquetes = [];
while ($row = $result->fetch_assoc()) {
    $paquetes[] = $row;
}
echo json_encode($paquetes);
?>¡