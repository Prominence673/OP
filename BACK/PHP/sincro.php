<?php
set_time_limit(0); // Quita límite de tiempo
// Configuración DB
$mysqli = new mysqli("localhost", "root", "", "paquetes_viajes");
if ($mysqli->connect_errno) {
    die("Falló la conexión a MySQL: " . $mysqli->connect_error);
}

// Función para hacer fetch JSON desde URL
function fetchJSON($url) {
    $json = file_get_contents($url);
    if (!$json) return null;
    return json_decode($json, true);
}

// Insertar o actualizar en provincia
function upsertProvincia($mysqli, $id, $nombre) {
    $stmt = $mysqli->prepare("INSERT INTO provincia (id_provincia, nombre) VALUES (?, ?) ON DUPLICATE KEY UPDATE nombre=VALUES(nombre)");
    $stmt->bind_param("ss", $id, $nombre);
    $stmt->execute();
    $stmt->close();
}

// Insertar o actualizar en partido
function upsertPartido($mysqli, $id, $nombre, $id_provincia) {
    $stmt = $mysqli->prepare("INSERT INTO partido (id_partido, nombre, id_provincia) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), id_provincia=VALUES(id_provincia)");
    $stmt->bind_param("sss", $id, $nombre, $id_provincia);
    $stmt->execute();
    $stmt->close();
}

// Insertar o actualizar en localidad
function upsertLocalidad($mysqli, $id, $nombre, $id_partido) {
    $stmt = $mysqli->prepare("INSERT INTO localidad (id_localidad, nombre, id_partido) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), id_partido=VALUES(id_partido)");
    $stmt->bind_param("sss", $id, $nombre, $id_partido);
    $stmt->execute();
    $stmt->close();
}

// Obtener todas las provincias
$provincias = fetchJSON('https://apis.datos.gob.ar/georef/api/provincias?campos=id,nombre&max=100')['provincias'] ?? [];

foreach ($provincias as $prov) {
    $idProv = $prov['id'];
    $nombreProv = $prov['nombre'];
    upsertProvincia($mysqli, $idProv, $nombreProv);
    
    // Obtener partidos de esa provincia
    $partidosUrl = "https://apis.datos.gob.ar/georef/api/departamentos?provincia={$idProv}&campos=id,nombre&max=300";
    $partidos = fetchJSON($partidosUrl)['departamentos'] ?? [];
    
    foreach ($partidos as $part) {
        $idPart = $part['id'];
        $nombrePart = $part['nombre'];
        upsertPartido($mysqli, $idPart, $nombrePart, $idProv);
        
        // Obtener localidades para cada partido
        $localidadesUrl = "https://apis.datos.gob.ar/georef/api/localidades?departamento={$idPart}&campos=id,nombre&max=500";
        $localidades = fetchJSON($localidadesUrl)['localidades'] ?? [];
        
        foreach ($localidades as $loc) {
            $idLoc = $loc['id'];
            $nombreLoc = $loc['nombre'];
            upsertLocalidad($mysqli, $idLoc, $nombreLoc, $idPart);
        }
    }
}

echo "Sincronización completada.\n";
$mysqli->close();