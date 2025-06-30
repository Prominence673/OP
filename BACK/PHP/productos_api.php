<?php
// Debug: loguea todo lo que recibe y responde el PHP
$debugFile = __DIR__ . '/debug_productos_api.txt';

// Loguea los parámetros recibidos
file_put_contents($debugFile, "---- NUEVA PETICIÓN ----\n", FILE_APPEND);
file_put_contents($debugFile, "GET: " . print_r($_GET, true) . "\n", FILE_APPEND);
file_put_contents($debugFile, "POST: " . print_r($_POST, true) . "\n", FILE_APPEND);

// Función para loguear la respuesta antes de enviarla
function log_and_echo($data) {
    global $debugFile;
    $json = json_encode($data);
    file_put_contents($debugFile, "RESPUESTA: $json\n\n", FILE_APPEND);
    echo $json;
    exit;
}

header('Content-Type: application/json');
include 'connection.php';

class ProductosAPI {
    private $conn;

    public function __construct($conn) {
        $this->conn = $conn;
    }

    public function getPaquetes() {
        $sql = "SELECT id_paquetes, nombre_viaje, imagen, duracion, incluye, precio_aprox FROM paquetes";
        $result = $this->conn->query($sql);
        $paquetes = [];
        while ($row = $result->fetch_assoc()) {
            $paquetes[] = $row;
        }
        return $paquetes;
    }

    public function getCoches() {
        $sql = "SELECT id_autos, nombre, imagen, tipo, capacidad, precio, imagen_interior FROM autos";
        $result = $this->conn->query($sql);
        $coches = [];
        while ($row = $result->fetch_assoc()) {
            $coches[] = $row;
        }
        return $coches;
    }

    public function getEstadias() {
        $sql = "SELECT id_estadias, nombre, imagen, imagen_interior, ubicacion, descripcion, precio FROM estadias";
        $result = $this->conn->query($sql);
        $estadias = [];
        while ($row = $result->fetch_assoc()) {
            $estadias[] = $row;
        }
        return $estadias;
    }

    public function getPasajes() {
        $sql = "SELECT id_pasajes, nombre, imagen, aerolinea, duracion, precio_desde, clase FROM pasajes";
        $result = $this->conn->query($sql);
        $pasajes = [];
        while ($row = $result->fetch_assoc()) {
            $pasajes[] = $row;
        }
        return $pasajes;
    }
}


$api = new ProductosAPI($conn);


$tipo = $_GET['tipo'] ?? '';

switch ($tipo) {
    case 'paquetes':
        log_and_echo($api->getPaquetes());
        break;
    case 'coches':
        log_and_echo($api->getCoches());
        break;
    case 'estadias':
        log_and_echo($api->getEstadias());
        break;
    case 'pasajes':
        log_and_echo($api->getPasajes());
        break;
    default:
        log_and_echo(['error' => 'Tipo no válido. Usar ?tipo=paquetes|coches|estadias|pasajes']);
        break;
}