<?php
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
        $sql = "SELECT id_autos, nombre, imagen, imagen_interior, tipo, capacidad, precio FROM autos";
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

// --- Uso de la API ---
$api = new ProductosAPI($conn);

// Determinar qué datos devolver según parámetro GET 'tipo'
$tipo = $_GET['tipo'] ?? '';

switch ($tipo) {
    case 'paquetes':
        echo json_encode($api->getPaquetes());
        break;
    case 'coches':
        echo json_encode($api->getCoches());
        break;
    case 'estadias':
        echo json_encode($api->getEstadias());
        break;
    case 'pasajes':
        echo json_encode($api->getPasajes());
        break;
    default:
        echo json_encode(['error' => 'Tipo no válido. Usar ?tipo=paquetes|coches|estadias|pasajes']);
        break;
}