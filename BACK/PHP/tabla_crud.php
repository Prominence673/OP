<?php
require_once "connection.php";
header("Content-Type: application/json");

$input = json_decode(file_get_contents("php://input"), true);
$tabla = $input["tabla"] ?? null;
$accion = $input["accion"] ?? null;
$id = $input["id"] ?? null;
$data = $input["data"] ?? [];

if (!$tabla || !$accion) {
    echo json_encode(["error" => "Faltan datos"]);
    exit;
}

// Obtener campos de la tabla
function getCampos($conn, $tabla) {
    $cols = [];
    $res = $conn->query("SHOW COLUMNS FROM `$tabla`");
    while ($row = $res->fetch_assoc()) {
        $cols[] = $row["Field"];
    }
    return $cols;
}

try {
    if ($accion === "add") {
        $campos = array_keys($data);
        $valores = array_map(function($v) use ($conn) { return "'".$conn->real_escape_string($v)."'"; }, array_values($data));
        $sql = "INSERT INTO `$tabla` (`".implode("`,`",$campos)."`) VALUES (".implode(",",$valores).")";
        $conn->query($sql);
        echo json_encode(["ok" => true, "id" => $conn->insert_id]);
    }
    elseif ($accion === "edit" && $id) {
        $sets = [];
        foreach ($data as $k => $v) {
            $sets[] = "`$k`='".$conn->real_escape_string($v)."'";
        }
        // Detectar campo id
        $idField = getCampos($conn, $tabla)[0];
        $sql = "UPDATE `$tabla` SET ".implode(",",$sets)." WHERE `$idField`='".intval($id)."'";
        $conn->query($sql);
        echo json_encode(["ok" => true]);
    }
    elseif ($accion === "soft_delete" && $id) {
        // Busca campo id_activo o similar
        $campos = getCampos($conn, $tabla);
        $campoActivo = in_array("id_activo", $campos) ? "id_activo" : (in_array("activo", $campos) ? "activo" : null);
        if (!$campoActivo) throw new Exception("No se encontró campo de activo en $tabla");
        $idField = $campos[0];
        $sql = "UPDATE `$tabla` SET `$campoActivo`=2 WHERE `$idField`='".intval($id)."'";
        $conn->query($sql);
        echo json_encode(["ok" => true]);
    }
    elseif ($accion === "hard_delete" && $id) {
        $idField = getCampos($conn, $tabla)[0];
        $sql = "DELETE FROM `$tabla` WHERE `$idField`='".intval($id)."'";
        $conn->query($sql);
        echo json_encode(["ok" => true]);
    }
    elseif ($accion === "campos") {
        echo json_encode(getCampos($conn, $tabla));
    }
    elseif ($accion === "get" && $id) {
        $idField = getCampos($conn, $tabla)[0];
        $res = $conn->query("SELECT * FROM `$tabla` WHERE `$idField`='".intval($id)."'");
        echo json_encode($res->fetch_assoc());
    }
    else {
        echo json_encode(["error" => "Acción no válida"]);
    }
} catch(Exception $e) {
    echo json_encode(["error" => $e->getMessage()]);
}