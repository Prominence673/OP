<?php
$host = "localhost";
$user = "root";
$pass = "";
$bd = "paquetes_viajes";

try {
    $conn = new mysqli($host, $username, $pass, $dbname);
    
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

} catch (Exception $e) {
    echo "Ocurrió un error en la conexión: " . $e->getMessage();
    die();
}
?>