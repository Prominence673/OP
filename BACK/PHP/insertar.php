<?php
include 'connection.php';

// Insertar paquetes faltantes
$conn->query("INSERT IGNORE INTO productos (tipo, id_referencia) 
    SELECT 'paquete', id_paquetes FROM paquetes");

// Insertar autos faltantes
$conn->query("INSERT IGNORE INTO productos (tipo, id_referencia) 
    SELECT 'auto', id_autos FROM autos");

// Insertar estadias faltantes
$conn->query("INSERT IGNORE INTO productos (tipo, id_referencia) 
    SELECT 'estadia', id_estadias FROM estadias");

// Insertar pasajes faltantes
$conn->query("INSERT IGNORE INTO productos (tipo, id_referencia) 
    SELECT 'pasaje', id_pasajes FROM pasajes");

echo "Sincronización de productos completada.";