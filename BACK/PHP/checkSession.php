<?php
session_start();
$response = [];

if (isset($_SESSION['usuario'])) {
    $response['loggedIn'] = true;
    $response['usuario'] = $_SESSION['usuario'];
} else {
    $response['loggedIn'] = false;
}

header('Content-Type: application/json');
echo json_encode($response);
?>