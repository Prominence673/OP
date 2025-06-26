<?php
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log.txt');
header('Content-Type: application/json');
require_once __DIR__ . '/../vendor/autoload.php';
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/../');
$dotenv->load();

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
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



    $stmt = $conn->prepare("INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, total, id_estado) VALUES (?, ?, ?, ?, ?, 1)");
    foreach ($resumen['items'] as $item) {
        $subtotal = $item['precio'] * $item['cantidad'];
        $stmt->bind_param("iiidd", $id_pedido, $item['id_producto'], $item['cantidad'], $item['precio'], $subtotal);
        $stmt->execute();
    }
    $stmt->close();
    $conn->query("UPDATE carrito SET estado='comprado' WHERE id_carrito=" . intval($resumen['id_carrito']));
    $conn->query("DELETE FROM carrito_items WHERE id_carrito=" . intval($resumen['id_carrito']));


    $email_usuario = '';
    $stmt = $conn->prepare("SELECT email FROM usuarios WHERE id_usuario = ?");
    $stmt->bind_param("i", $id_usuario);
    $stmt->execute();
    $stmt->bind_result($email_usuario);
    $stmt->fetch();
    $stmt->close();
 
    

    $mail = new PHPMailer(true);
    try {
        $mail->isSMTP();
        $mail->Host = 'smtp.gmail.com';
        $mail->SMTPAuth = true;
        $mail->Username = $_ENV['EMAIL_USER'];
        $mail->Password = $_ENV['EMAIL_PASS'];
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;

        $mail->setFrom($_ENV['EMAIL_USER'], 'TravelAir');
        $mail->addAddress($email_usuario);

        $mail->isHTML(true);
        $mail->Subject = '¡Gracias por tu compra en TravelAir!';


        $productosHtml = '';
        foreach ($resumen['items'] as $item) {
            $productosHtml .= "<tr>
                <td style='padding:8px;border-bottom:1px solid #eee;'>{$item['nombre']}</td>
                <td style='padding:8px;border-bottom:1px solid #eee;'>{$item['cantidad']}</td>
                <td style='padding:8px;border-bottom:1px solid #eee;'>$" . number_format($item['precio'], 2) . "</td>
                <td style='padding:8px;border-bottom:1px solid #eee;'>$" . number_format($item['total'], 2) . "</td>
            </tr>";
        }

        $mail->Body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: auto; border-radius: 8px; overflow: hidden;'>
            <div style='background-color: #0077cc; height: 50px;'></div>
            <div style='background-color: #ffffff; padding: 40px; text-align: center;'>
                <h2 style='color: #333;'>¡Gracias por tu compra en TravelAir!</h2>
                <p style='color: #555;'>Hola <strong>{$nombre} {$apellido}</strong>,</p>
                <p style='color: #555;'>Tu pedido <strong>#{$id_pedido}</strong> ha sido recibido correctamente.</p>
                <p style='color: #555;'>Estos son los productos que compraste:</p>
                <table style='width:100%;border-collapse:collapse;margin:20px 0;'>
                    <thead>
                        <tr style='background:#f5f5f5;'>
                            <th style='padding:8px;'>Producto</th>
                            <th style='padding:8px;'>Cantidad</th>
                            <th style='padding:8px;'>Precio unitario</th>
                            <th style='padding:8px;'>Total</th>
                        </tr>
                    </thead>
                    <tbody>
                        {$productosHtml}
                    </tbody>
                </table>
                <p style='color: #333; font-size: 1.1em;'><strong>Total pagado: $" . number_format($total, 2) . "</strong></p>
                <p style='color: #555;'>¡Gracias por confiar en nosotros!<br>El equipo de TravelAir</p>
            </div>
            <div style='background-color: #0077cc; height: 50px;'></div>
        </div>";

        $mail->send();
 
    } catch (Exception $e) {
        error_log("No se pudo enviar el correo de agradecimiento: {$mail->ErrorInfo}");
    }

    responder("Compra realizada con éxito", true, [
        "success" => true,
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