<?php
header('Content-Type: application/json');
require_once 'connection.php';

// Detectar tipo de request
$contentType = $_SERVER['CONTENT_TYPE'] ?? '';
$isJson = stripos($contentType, 'application/json') !== false;

if ($isJson) {
    $data = json_decode(file_get_contents('php://input'), true) ?? [];
    $tabla = $data['tabla'] ?? '';
    $accion = $data['accion'] ?? '';
    $id = $data['id'] ?? null;
} else {
    $tabla = $_POST['tabla'] ?? $_GET['tabla'] ?? '';
    $accion = $_POST['accion'] ?? $_GET['accion'] ?? '';
    $id = $_POST['id'] ?? $_GET['id'] ?? null;
    $data = $_POST;
}

// Validar tabla
$tablas_validas = ['autos', 'pasajes', 'paquetes', 'estadias'];
if (!in_array($tabla, $tablas_validas)) {
    echo json_encode(['error' => 'Tabla no válida']);
    exit;
}

// --- INSERTAR ---
if ($accion === 'insertar') {
    switch ($tabla) {
        case 'autos':
            // Si viene archivo, procesar imagen
            $imagen = $data['imagen'] ?? '';
            if (isset($_FILES['imagen']) && $_FILES['imagen']['error'] === UPLOAD_ERR_OK) {
                $nombreArchivo = uniqid('auto_') . '_' . basename($_FILES['imagen']['name']);
                $rutaDestino = '../../FRONT/IMG/' . $nombreArchivo;
                move_uploaded_file($_FILES['imagen']['tmp_name'], $rutaDestino);
                $imagen = $nombreArchivo;
            }
            $stmt = $conn->prepare("INSERT INTO autos (nombre, imagen, tipo, capacidad, precio, imagen_interior) VALUES (?, ?, ?, ?, ?)");
            $stmt->bind_param("sssiis", $data['nombre'], $imagen, $data['tipo'], $data['capacidad'], $data['precio']);
            break;
        case 'pasajes':
            $stmt = $conn->prepare("INSERT INTO pasajes (nombre, imagen, aerolinea, duracion, precio_desde, clase) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("ssssds", $data['nombre'], $data['imagen'], $data['aerolinea'], $data['duracion'], $data['precio_desde'], $data['clase']);
            break;
        case 'paquetes':
            $stmt = $conn->prepare("INSERT INTO paquetes (nombre_viaje, imagen, duracion, incluye, precio_aprox) VALUES (?, ?, ?, ?, ?)");
            $stmt->bind_param("ssssd", $data['nombre_viaje'], $data['imagen'], $data['duracion'], $data['incluye'], $data['precio_aprox']);
            break;
        case 'estadias':
            $stmt = $conn->prepare("INSERT INTO estadias (nombre, imagen, imagen_interior, ubicacion, descripcion, precio) VALUES (?, ?, ?, ?, ?)");
            $stmt->bind_param("sssssd", $data['nombre'], $data['imagen'], $data['ubicacion'], $data['descripcion'], $data['precio']);
            break;
    }
    if ($stmt->execute()) {
        echo json_encode(['mensaje' => 'Insertado correctamente']);
    } else {
        echo json_encode(['error' => $stmt->error]);
    }
    exit;
}

// --- MODIFICAR ---
if ($accion === 'modificar' && $id) {
    switch ($tabla) {
        case 'autos':
            $imagen = $data['imagen'] ?? '';
            if (isset($_FILES['imagen']) && $_FILES['imagen']['error'] === UPLOAD_ERR_OK) {
                $nombreArchivo = uniqid('auto_') . '_' . basename($_FILES['imagen']['name']);
                $rutaDestino = '../../FRONT/IMG/' . $nombreArchivo;
                move_uploaded_file($_FILES['imagen']['tmp_name'], $rutaDestino);
                $imagen = $nombreArchivo;
            }
            $stmt = $conn->prepare("UPDATE autos SET nombre=?, imagen=?, tipo=?, capacidad=?, precio=? WHERE id_autos=?");
            $stmt->bind_param("sssiii", $data['nombre'], $imagen, $data['tipo'], $data['capacidad'], $data['precio'], $id);
            break;
        case 'pasajes':
            $stmt = $conn->prepare("UPDATE pasajes SET nombre=?, imagen=?, aerolinea=?, duracion=?, precio_desde=?, clase=? WHERE id_pasajes=?");
            $stmt->bind_param("ssssdsi", $data['nombre'], $data['imagen'], $data['aerolinea'], $data['duracion'], $data['precio_desde'], $data['clase'], $id);
            break;
        case 'paquetes':
            $stmt = $conn->prepare("UPDATE paquetes SET nombre_viaje=?, imagen=?, duracion=?, incluye=?, precio_aprox=? WHERE id_paquetes=?");
            $stmt->bind_param("ssssdi", $data['nombre_viaje'], $data['imagen'], $data['duracion'], $data['incluye'], $data['precio_aprox'], $id);
            break;
        case 'estadias':
            $stmt = $conn->prepare("UPDATE estadias SET nombre=?, imagen=?, ubicacion=?, descripcion=?, precio=? WHERE id_estadias=?");
            $stmt->bind_param("ssssdi", $data['nombre'], $data['imagen'], $data['ubicacion'], $data['descripcion'], $data['precio'], $id);
            break;
    }
    if ($stmt->execute()) {
        echo json_encode(['mensaje' => 'Modificado correctamente']);
    } else {
        echo json_encode(['error' => $stmt->error]);
    }
    exit;
}

// --- BORRAR ---
if ($accion === 'borrar' && $id) {
    switch ($tabla) {
        case 'autos':
            $stmt = $conn->prepare("DELETE FROM autos WHERE id_autos=?");
            $stmt->bind_param("i", $id);
            break;
        case 'pasajes':
            $stmt = $conn->prepare("DELETE FROM pasajes WHERE id_pasajes=?");
            $stmt->bind_param("i", $id);
            break;
        case 'paquetes':
            $stmt = $conn->prepare("DELETE FROM paquetes WHERE id_paquetes=?");
            $stmt->bind_param("i", $id);
            break;
        case 'estadias':
            $stmt = $conn->prepare("DELETE FROM estadias WHERE id_estadias=?");
            $stmt->bind_param("i", $id);
            break;
    }
    if ($stmt->execute()) {
        echo json_encode(['mensaje' => 'Borrado correctamente']);
    } else {
        echo json_encode(['error' => $stmt->error]);
    }
    exit;
}

echo json_encode(['error' => 'Acción no válida o faltan parámetros']);
exit;