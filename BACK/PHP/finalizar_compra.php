<?php
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
header('Content-Type: application/json');
require_once 'connection.php';

function responder($mensaje, $ok = true, $extra = []) {
    echo json_encode(array_merge([$ok ? 'mensaje' : 'error' => $mensaje], $extra));
    exit;
}

function obtenerResumenCarrito($conn, $id_usuario, $id_pagometodo) {
    $id_carrito = null;
    $porcentaje = 0.0;


    $stmt = $conn->prepare("SELECT id_carrito FROM carrito WHERE id_usuario=? AND estado='activo' ORDER BY fecha_creacion DESC LIMIT 1");
    $stmt->bind_param("i", $id_usuario);
    $stmt->execute();
    $stmt->bind_result($id_carrito);
    $stmt->fetch();
    $stmt->close();
    if (!$id_carrito) return null;


    $stmt = $conn->prepare("SELECT d.porcentaje FROM pagometodo p LEFT JOIN descuento d ON p.id_descuento = d.id_descuento WHERE p.id_pagometodo = ?");
    $stmt->bind_param("i", $id_pagometodo);
    $stmt->execute();
    $stmt->bind_result($porcentaje);
    $stmt->fetch();
    $stmt->close();
    if (!$porcentaje) $porcentaje = 0.0;


    $query = "
        SELECT 
            ci.id_producto, 
            ci.cantidad, 
            ci.tipo,
            IF(ci.tipo = 'paquete', paquetes.nombre_viaje,
                IF(ci.tipo = 'auto', autos.nombre,
                    IF(ci.tipo = 'estadia', estadias.nombre,
                        IF(ci.tipo = 'pasaje', pasajes.nombre, 'Desconocido')
                    )
                )
            ) AS nombre,
            IF(ci.tipo = 'paquete', paquetes.precio_aprox,
                IF(ci.tipo = 'auto', autos.precio,
                    IF(ci.tipo = 'estadia', estadias.precio,
                        IF(ci.tipo = 'pasaje', pasajes.precio_desde, 0)
                    )
                )
            ) AS precio
        FROM carrito_items ci
        INNER JOIN productos prod ON ci.id_producto = prod.id_producto
        LEFT JOIN paquetes ON ci.tipo = 'paquete' AND prod.id_referencia = paquetes.id_paquetes
        LEFT JOIN autos ON ci.tipo = 'auto' AND prod.id_referencia = autos.id_autos
        LEFT JOIN estadias ON ci.tipo = 'estadia' AND prod.id_referencia = estadias.id_estadias
        LEFT JOIN pasajes ON ci.tipo = 'pasaje' AND prod.id_referencia = pasajes.id_pasajes
        WHERE ci.id_carrito = ?
    ";
    $stmt = $conn->prepare($query);
    $stmt->bind_param("i", $id_carrito);
    $stmt->execute();
    $result = $stmt->get_result();

    $items = [];
    $subtotal = 0.0;
    while ($row = $result->fetch_assoc()) {
        $row['total'] = $row['precio'] * $row['cantidad'];
        $subtotal += $row['total'];
        $items[] = $row;
    }
    $stmt->close();

   
    error_log("Query ejecutada para carrito $id_carrito, pagometodo $id_pagometodo");


    error_log("Items encontrados: " . print_r($items, true));

    $total = $subtotal - ($subtotal * $porcentaje / 100);

    return [
        'id_carrito' => $id_carrito,
        'items' => $items,
        'subtotal' => number_format($subtotal, 2, '.', ''),
        'total' => number_format($total, 2, '.', ''),
        'descuento' => $porcentaje
    ];
}

function finalizarCompra($conn, $id_usuario, $id_pagometodo, $nombre, $apellido, $dni, $datos_tarjeta = null) {
    $resumen = obtenerResumenCarrito($conn, $id_usuario, $id_pagometodo);
    if (!$resumen || empty($resumen['items'])) {
        responder("Carrito vacío o no encontrado", false);
    }

  
    if ($datos_tarjeta && isset($datos_tarjeta['numero'])) {
        $stmt = $conn->prepare("INSERT INTO tarjeta (id_usuario, numero, nombre_tarjeta, vencimiento, codigo_seguridad) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("issss", $id_usuario, $datos_tarjeta['numero'], $datos_tarjeta['nombre_tarjeta'], $datos_tarjeta['vencimiento'], $datos_tarjeta['cvv']);
        $stmt->execute();
        $stmt->close();
    }


    $stmt = $conn->prepare("INSERT INTO pedido (id_usuario, id_pagometodo, total, nombre, apellido, dni) VALUES (?, ?, ?, ?, ?, ?)");
    $total = floatval($resumen['total']);
    $stmt->bind_param("iidsss", $id_usuario, $id_pagometodo, $total, $nombre, $apellido, $dni);
    $stmt->execute();
    $id_pedido = $stmt->insert_id;
    $stmt->close();


    $stmt = $conn->prepare("INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, total) VALUES (?, ?, ?, ?, ?)");
    foreach ($resumen['items'] as $item) {
        $subtotal = $item['precio'] * $item['cantidad'];
        $stmt->bind_param("iiidd", $id_pedido, $item['id_producto'], $item['cantidad'], $item['precio'], $subtotal);
        $stmt->execute();
    }
    $stmt->close();
    $conn->query("UPDATE carrito SET estado='comprado' WHERE id_carrito=" . intval($resumen['id_carrito']));
    $conn->query("DELETE FROM carrito_items WHERE id_carrito=" . intval($resumen['id_carrito']));

    responder("Compra realizada con éxito", true, [
        "id_pedido" => $id_pedido,
        "total" => $total
    ]);
}

try {
    session_start();
    if (!isset($_SESSION['usuario'])) responder("No logueado", false);

    $id_usuario = $_SESSION['usuario']['id'] ?? null;
    if (!$id_usuario) responder("ID de usuario no encontrado en sesión", false);

    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    if (isset($data['soloResumen']) && $data['soloResumen']) {
        $id_pagometodo = $data['id_pagometodo'] ?? 1;
        $resumen = obtenerResumenCarrito($conn, $id_usuario, $id_pagometodo);
        if (!$resumen) responder("Carrito vacío o no encontrado", false);
        responder("Resumen obtenido", true, $resumen);
    }

 
    $id_pagometodo = $data['id_pagometodo'] ?? 1;
    $nombre = $data['nombre'] ?? '';
    $apellido = $data['apellido'] ?? '';
    $dni = $data['dni'] ?? '';
    $datos_tarjeta = null;
    if (isset($data['numero'])) {
        $datos_tarjeta = [
            'numero' => $data['numero'],
            'nombre_tarjeta' => $data['nombre_tarjeta'] ?? '',
            'vencimiento' => $data['vencimiento'] ?? '',
            'cvv' => $data['cvv'] ?? ''
        ];
    }
    finalizarCompra($conn, $id_usuario, $id_pagometodo, $nombre, $apellido, $dni, $datos_tarjeta);

} catch (Exception $e) {
    error_log("Error: " . $e->getMessage());
    responder("Error interno del servidor: " . $e->getMessage(), false);
}
?>