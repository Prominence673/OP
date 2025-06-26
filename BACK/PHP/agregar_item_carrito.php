<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

require_once 'connection.php';


file_put_contents('debug_input.log', file_get_contents("php://input"), FILE_APPEND);

$input = json_decode(file_get_contents("php://input"), true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(["error" => "JSON inválido: " . json_last_error_msg()]);
    exit;
}


session_start();
$id_usuario = $_SESSION['usuario']["id"];
$id_paquete = $input["id_paquete"] ?? null;
$cantidad = $input["cantidad"] ?? 1; 

if (!$id_paquete) {
    echo json_encode(["error" => "Falta el ID del paquete."]);
    exit;
}

try {
    $stmt = $conn->prepare("CALL SPAgregarItemACarrito(?, ?, ?)");
    $stmt->bind_param("iii", $id_usuario, $id_paquete, $cantidad);
    $stmt->execute();


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