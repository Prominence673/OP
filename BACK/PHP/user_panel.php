<?php
require_once 'connection.php';
require_once 'user_panelModel.php';
require_once 'loginModel.php';
require_once 'registerModel.php';
$panel = new userPanel($conn);
$login = new loginModel($conn);
$panel = new registerModel($conn);
$action = $panel->bringInput($datos['action']);
try{
    switch($action){
    case "aFoto":
        
    break;
    case "aDatos":

    break;
    case "aTelefono":

    break;
    case "aEmail":

    break;

    break;
    case "aPassword":

    break;
    default:
        json_decode("No es una opcion valida");
    } 

} catch (Exception $e) {
    json_decode("Error detectado.", $e->getMessage());
}
?>