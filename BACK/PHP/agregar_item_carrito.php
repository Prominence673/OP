<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once 'connection.php';

// Para depuración - registrar la entrada recibida
file_put_contents('debug_input.log', file_get_contents("php://input"), FILE_APPEND);

$input = json_decode(file_get_contents("php://input"), true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(["error" => "JSON inválido: " . json_last_error_msg()]);
    exit;
}

// ID de prueba (hardcodeado temporalmente)
$id_usuario = 2;
$id_paquete = $input["id_paquete"] ?? null;
$cantidad = $input["cantidad"] ?? 1; // Valor por defecto 1 si no se especifica

if (!$id_paquete) {
    echo json_encode(["error" => "Falta el ID del paquete."]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL SPAgregarItemACarrito(?, ?, ?)");
    $stmt->bind_param("iii", $id_usuario, $id_paquete, $cantidad);
    $stmt->execute();

    // Verificar si realmente se insertó
    if ($stmt->affected_rows > 0) {
        echo json_encode(["mensaje" => "Producto agregado al carrito correctamente"]);
    } else {
        echo json_encode(["error" => "No se pudo agregar el producto al carrito"]);
    }
    
    $stmt->close();
} catch (Exception $e) {
    echo json_encode(["error" => "Error en la base de datos: " . $e->getMessage()]);
} finally {
    $conn->close();
}
?>