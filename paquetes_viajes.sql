-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 26-06-2025 a las 22:45:03
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `paquetes_viajes`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `SPAgregarAlCarrito` (IN `p_id_usuario` INT, IN `p_id_paquete` INT, IN `p_cantidad` INT)   BEGIN
    DECLARE v_id_carrito INT;

    -- Buscar si el usuario ya tiene un carrito
    SELECT id_carrito INTO v_id_carrito
    FROM carrito
    WHERE id_usuario = p_id_usuario
    ORDER BY fecha_creacion DESC
    LIMIT 1;

    -- Si no tiene, crear uno nuevo
    IF v_id_carrito IS NULL THEN
        INSERT INTO carrito (id_usuario) VALUES (p_id_usuario);
        SET v_id_carrito = LAST_INSERT_ID();
    END IF;

    -- Verificar si ya está el paquete en el carrito
    IF EXISTS (
        SELECT 1 FROM carrito_items 
        WHERE id_carrito = v_id_carrito AND id_paquete = p_id_paquete
    ) THEN
        -- Actualizar cantidad
        UPDATE carrito_items 
        SET cantidad = cantidad + p_cantidad 
        WHERE id_carrito = v_id_carrito AND id_paquete = p_id_paquete;
    ELSE
        -- Insertar nuevo ítem
        INSERT INTO carrito_items (id_carrito, id_paquete, cantidad)
        VALUES (v_id_carrito, p_id_paquete, p_cantidad);
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPBringPassword` (IN `p_email` VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)   BEGIN
  SELECT contraseña FROM usuarios WHERE email COLLATE utf8mb4_unicode_ci = p_email COLLATE utf8mb4_unicode_ci;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPbrinUser` (IN `correo` VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)   BEGIN
    SELECT * FROM usuarios WHERE email COLLATE utf8mb4_unicode_ci = correo COLLATE utf8mb4_unicode_ci;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPChangePassword` (IN `p_email` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, IN `p_hash_password` VARCHAR(255))   BEGIN
    UPDATE usuarios
    SET contraseña = p_hash_password
    WHERE email COLLATE utf8mb4_unicode_ci = p_email COLLATE utf8mb4_unicode_ci
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPFinalizarCompra` (IN `p_id_usuario` INT, IN `p_nombre` VARCHAR(100), IN `p_apellido` VARCHAR(100), IN `p_dni` VARCHAR(20), IN `p_id_pagometodo` INT)   BEGIN
    DECLARE v_id_carrito INT;
    DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_id_descuento INT DEFAULT NULL;
    DECLARE v_porcentaje_descuento DECIMAL(5,2) DEFAULT 0.00;
    DECLARE v_id_pedido INT;
    
    -- Buscar el carrito activo del usuario
    SELECT id_carrito INTO v_id_carrito
    FROM carrito
    WHERE id_usuario = p_id_usuario AND estado = 'activo'
    ORDER BY fecha_creacion DESC
    LIMIT 1;

    IF v_id_carrito IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Carrito no encontrado';
    END IF;

    -- Obtener el descuento asociado al método de pago
    SELECT id_descuento INTO v_id_descuento
    FROM pagometodo
    WHERE id_pagometodo = p_id_pagometodo;

    -- Si hay descuento, obtener el porcentaje
    IF v_id_descuento IS NOT NULL THEN
        SELECT porcentaje INTO v_porcentaje_descuento
        FROM descuento
        WHERE id_descuento = v_id_descuento
          AND CURDATE() BETWEEN inicio AND fin;
    END IF;

    -- Calcular el total del carrito
    SELECT SUM(
        (SELECT 
            CASE 
                WHEN tipo = 'paquete' THEN (SELECT precio_aprox FROM paquetes WHERE id_producto = ci.id_producto)
                WHEN tipo = 'auto' THEN (SELECT precio FROM autos WHERE id_producto = ci.id_producto)
                WHEN tipo = 'estadia' THEN (SELECT precio FROM estadias WHERE id_producto = ci.id_producto)
                WHEN tipo = 'pasaje' THEN (SELECT precio_desde FROM pasajes WHERE id_producto = ci.id_producto)
                ELSE 0
            END
        ) * ci.cantidad
    ) INTO v_total
    FROM carrito_items ci
    WHERE ci.id_carrito = v_id_carrito;

    -- Aplicar descuento si corresponde
    IF v_porcentaje_descuento > 0 THEN
        SET v_total = v_total - (v_total * v_porcentaje_descuento / 100);
    END IF;

    -- Insertar en tabla pedido
    INSERT INTO pedido (
        id_usuario, id_pagometodo, id_descuento, total, fecha, nombre, apellido, dni
    )
    VALUES (
        p_id_usuario, p_id_pagometodo, v_id_descuento, v_total, NOW(), p_nombre, p_apellido, p_dni
    );

    SET v_id_pedido = LAST_INSERT_ID();

    -- Insertar los productos del carrito en detalle_pedido
    INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario, total)
    SELECT
        v_id_pedido,
        ci.id_producto,
        ci.cantidad,
        CASE 
            WHEN ci.tipo = 'paquete' THEN (SELECT precio_aprox FROM paquetes WHERE id_producto = ci.id_producto)
            WHEN ci.tipo = 'auto' THEN (SELECT precio FROM autos WHERE id_producto = ci.id_producto)
            WHEN ci.tipo = 'estadia' THEN (SELECT precio FROM estadias WHERE id_producto = ci.id_producto)
            WHEN ci.tipo = 'pasaje' THEN (SELECT precio_desde FROM pasajes WHERE id_producto = ci.id_producto)
            ELSE 0
        END AS precio_unitario,
        CASE 
            WHEN ci.tipo = 'paquete' THEN (SELECT precio_aprox FROM paquetes WHERE id_producto = ci.id_producto) * ci.cantidad
            WHEN ci.tipo = 'auto' THEN (SELECT precio FROM autos WHERE id_producto = ci.id_producto) * ci.cantidad
            WHEN ci.tipo = 'estadia' THEN (SELECT precio FROM estadias WHERE id_producto = ci.id_producto) * ci.cantidad
            WHEN ci.tipo = 'pasaje' THEN (SELECT precio_desde FROM pasajes WHERE id_producto = ci.id_producto) * ci.cantidad
            ELSE 0
        END AS total
    FROM carrito_items ci
    WHERE ci.id_carrito = v_id_carrito;

    -- Cambiar estado del carrito
    UPDATE carrito
    SET estado = 'comprado'
    WHERE id_carrito = v_id_carrito;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPGetEmailResetByToken` (IN `p_token` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)   BEGIN
    SELECT *
    FROM email_resets
    WHERE token COLLATE utf8mb4_unicode_ci = p_token COLLATE utf8mb4_unicode_ci
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPGetPasswordResetByToken` (IN `p_token` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)   BEGIN
    SELECT id_usuario, expires_at
    FROM password_resets
    WHERE token COLLATE utf8mb4_unicode_ci = p_token COLLATE utf8mb4_unicode_ci;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPGuardarTarjeta` (IN `p_id_usuario` INT, IN `p_numero` VARCHAR(20), IN `p_nombre_tarjeta` VARCHAR(100), IN `p_vencimiento` DATE, IN `p_codigo_seguridad` VARCHAR(10))   BEGIN
  INSERT INTO tarjeta (id_usuario, numero, nombre_tarjeta, vencimiento, codigo_seguridad)
  VALUES (p_id_usuario, p_numero, p_nombre_tarjeta, p_vencimiento, p_codigo_seguridad);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPInsertEmailReset` (IN `p_id_usuario` INT, IN `p_token` VARCHAR(64), IN `p_expires_at` DATETIME)   BEGIN
    INSERT INTO email_resets (id_usuario, token, expires_at, creado_en)
    VALUES (p_id_usuario, p_token, p_expires_at, NOW());
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPInsertPasswordReset` (IN `p_id_usuario` INT, IN `p_token` VARCHAR(64), IN `p_expires_at` DATETIME)   BEGIN
    INSERT INTO password_resets (id_usuario, token, expires_at)
    VALUES (p_id_usuario, p_token, p_expires_at);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPRegistrarUsuario` (IN `p_user` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_password` VARCHAR(255))   BEGIN
    INSERT INTO usuarios (usuario_nombre, email, contraseña)
    VALUES (p_user, p_email, p_password);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPResetPasswordAndDeleteToken` (IN `p_token` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci, IN `p_new_password` VARCHAR(255))   BEGIN
    DECLARE v_id_usuario INT;

    -- Obtener el ID del usuario con ese token
    SELECT id_usuario INTO v_id_usuario
    FROM password_resets
    WHERE token COLLATE utf8mb4_unicode_ci = p_token COLLATE utf8mb4_unicode_ci;

    -- Actualizar contraseña
    UPDATE usuarios
    SET contraseña = p_new_password
    WHERE id_usuario = v_id_usuario;

    -- Eliminar token
    DELETE FROM password_resets
    WHERE token COLLATE utf8mb4_unicode_ci = p_token COLLATE utf8mb4_unicode_ci;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUpdateEmail` (IN `p_email` VARCHAR(100), IN `p_id_usuario` INT)   BEGIN
  UPDATE usuarios
  SET email = p_email
  WHERE id_usuario = p_id_usuario;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUpdateImg` (IN `p_id_usuario` INT, IN `p_imagen_usuario` VARCHAR(255))   BEGIN
  DECLARE existe INT;

  SELECT COUNT(*) INTO existe 
  FROM datos_personales 
  WHERE id_usuario = p_id_usuario;

  IF existe > 0 THEN
    -- Actualiza solo la imagen si ya existe el registro
    UPDATE datos_personales
    SET imagen_usuario = p_imagen_usuario
    WHERE id_usuario = p_id_usuario;
  ELSE
    -- Inserta solo el id y la imagen si no existe el registro
    INSERT INTO datos_personales (id_usuario, imagen_usuario)
    VALUES (p_id_usuario, p_imagen_usuario);
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUpdateInfo` (IN `p_id_usuario` INT, IN `p_nombre` VARCHAR(50), IN `p_apellido` VARCHAR(50), IN `p_fecha_nacimiento` DATE, IN `p_sexo` VARCHAR(20))   BEGIN
  DECLARE existe INT;

  SELECT COUNT(*) INTO existe FROM datos_personales WHERE id_usuario = p_id_usuario;

  IF existe > 0 THEN
    -- Actualiza si ya existe
    UPDATE datos_personales
    SET nombre = p_nombre,
        apellido = p_apellido,
        fecha_nacimiento = p_fecha_nacimiento,
        sexo = p_sexo
    WHERE id_usuario = p_id_usuario;
  ELSE
    -- Inserta si no existe
    INSERT INTO datos_personales (id_usuario, nombre, apellido, fecha_nacimiento, sexo)
    VALUES (p_id_usuario, p_nombre, p_apellido, p_fecha_nacimiento, p_sexo);
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUpdateNumber` (IN `p_id_usuario` INT, IN `p_telefono` VARCHAR(30))   BEGIN
  DECLARE existe INT;

  SELECT COUNT(*) INTO existe FROM datos_personales WHERE id_usuario = p_id_usuario;

  IF existe > 0 THEN
    UPDATE datos_personales
    SET telefono = p_telefono
    WHERE id_usuario = p_id_usuario;
  ELSE
    INSERT INTO datos_personales (id_usuario, telefono)
    VALUES (p_id_usuario, p_telefono);
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUpdatePassword` (IN `p_password` VARCHAR(255), IN `p_id_usuario` INT)   BEGIN UPDATE usuarios SET contraseña = p_password WHERE id_usuario = p_id_usuario; 
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUserExists` (IN `p_email` VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)   BEGIN
SELECT usuario_nombre FROM usuarios WHERE email COLLATE utf8mb4_unicode_ci = p_email COLLATE utf8mb4_unicode_ci;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `acciones_admins`
--

CREATE TABLE `acciones_admins` (
  `id_accion` int(11) NOT NULL,
  `id_admin` int(11) DEFAULT NULL,
  `accion` varchar(100) DEFAULT NULL,
  `fecha` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `admins`
--

CREATE TABLE `admins` (
  `id_admin` int(11) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `apellido` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `rol` enum('superadmin','editor') DEFAULT 'editor'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `alojamientos`
--

CREATE TABLE `alojamientos` (
  `id_alojamiento` int(11) NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `direccion` varchar(255) DEFAULT NULL,
  `ciudad` varchar(100) DEFAULT NULL,
  `tipo` varchar(50) DEFAULT NULL,
  `estrellas` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `autos`
--

CREATE TABLE `autos` (
  `id_autos` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `imagen` varchar(255) DEFAULT NULL,
  `tipo` varchar(50) DEFAULT NULL,
  `capacidad` int(11) DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `id_producto` int(11) DEFAULT NULL,
  `imagen_interior` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `autos`
--

INSERT INTO `autos` (`id_autos`, `nombre`, `imagen`, `tipo`, `capacidad`, `precio`, `id_producto`, `imagen_interior`) VALUES
(1, 'CHEVROLET ONIX', '../../SOURCE/RESOURCES/COCHES/onix.avif', 'Económico', 5, 18000.00, NULL, '../../SOURCE/RESOURCES/COCHES/onix-interior.jpg'),
(3, 'TOYOTA COROLLA', '../../SOURCE/RESOURCES/COCHES/corolla.jpeg', 'Sedán', 5, 25000.00, NULL, '../../SOURCE/RESOURCES/COCHES/corolla-interior.jpeg'),
(4, 'RENAULT DUSTER', '../../SOURCE/RESOURCES/COCHES/duster.webp', 'SUV', 5, 28000.00, NULL, '../../SOURCE/RESOURCES/COCHES/duster-interior.jpg'),
(5, 'FORD MUSTANG', '../../SOURCE/RESOURCES/COCHES/mustang.avif', 'Deportivo', 4, 120000.00, NULL, '../../SOURCE/RESOURCES/COCHES/mustang-interior.jpg'),
(6, 'JEEP WRANGLER', '../../SOURCE/RESOURCES/COCHES/wrangler.png', 'SUV 4x4', 5, 160000.00, NULL, '../../SOURCE/RESOURCES/COCHES/wrangler-interior.jpg');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `carrito`
--

CREATE TABLE `carrito` (
  `id_carrito` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `fecha_creacion` datetime DEFAULT current_timestamp(),
  `estado` enum('activo','comprado','cancelado') DEFAULT 'activo'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `carrito`
--

INSERT INTO `carrito` (`id_carrito`, `id_usuario`, `fecha_creacion`, `estado`) VALUES
(1, NULL, '2025-06-25 11:15:39', 'activo'),
(2, NULL, '2025-06-25 11:37:11', 'activo'),
(3, NULL, '2025-06-25 11:41:54', 'activo'),
(4, NULL, '2025-06-25 11:42:18', 'activo'),
(5, NULL, '2025-06-25 11:42:20', 'activo'),
(6, NULL, '2025-06-25 11:42:22', 'activo'),
(7, NULL, '2025-06-25 11:42:23', 'activo'),
(8, NULL, '2025-06-25 16:50:44', 'activo'),
(9, NULL, '2025-06-25 16:50:49', 'activo'),
(10, NULL, '2025-06-25 16:52:15', 'activo'),
(11, NULL, '2025-06-25 16:52:55', 'activo'),
(12, NULL, '2025-06-25 16:53:08', 'activo'),
(13, 39, '2025-06-25 16:55:06', 'comprado'),
(14, 39, '2025-06-26 02:00:57', 'comprado'),
(15, 39, '2025-06-26 03:32:08', 'comprado'),
(16, 39, '2025-06-26 04:30:08', 'comprado'),
(17, 39, '2025-06-26 04:35:31', 'comprado'),
(18, 39, '2025-06-26 04:47:50', 'comprado'),
(19, 39, '2025-06-26 04:51:56', 'comprado'),
(20, 39, '2025-06-26 05:00:49', 'comprado'),
(21, 39, '2025-06-26 05:06:09', 'comprado'),
(22, 39, '2025-06-26 05:12:36', 'comprado'),
(23, 39, '2025-06-26 05:15:05', 'comprado'),
(24, 39, '2025-06-26 05:21:53', 'comprado'),
(25, 39, '2025-06-26 05:24:58', 'comprado');

--
-- Disparadores `carrito`
--
DELIMITER $$
CREATE TRIGGER `limpiar_carrito_cancelado` AFTER UPDATE ON `carrito` FOR EACH ROW BEGIN
  IF NEW.estado = 'cancelado' THEN
    DELETE FROM carrito_items WHERE id_carrito = NEW.id_carrito;
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `carrito_items`
--

CREATE TABLE `carrito_items` (
  `id_item` int(11) NOT NULL,
  `id_carrito` int(11) DEFAULT NULL,
  `tipo` varchar(20) NOT NULL,
  `cantidad` int(11) DEFAULT 1,
  `id_producto` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `datos_personales`
--

CREATE TABLE `datos_personales` (
  `id_dato` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `apellido` varchar(50) DEFAULT NULL,
  `fecha_nacimiento` date DEFAULT NULL,
  `sexo` enum('Masculino','Femenino','Otro') DEFAULT 'Otro',
  `telefono` varchar(20) DEFAULT NULL,
  `id_pasajero` int(11) DEFAULT NULL,
  `dni` varchar(15) NOT NULL,
  `id_localidad` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `descuento`
--

CREATE TABLE `descuento` (
  `id_descuento` int(11) NOT NULL,
  `razon` varchar(255) DEFAULT NULL,
  `porcentaje` decimal(5,2) DEFAULT NULL,
  `inicio` date DEFAULT NULL,
  `fin` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `descuento`
--

INSERT INTO `descuento` (`id_descuento`, `razon`, `porcentaje`, `inicio`, `fin`) VALUES
(1, 'Descuento por pago en efectivo', 10.00, '2025-06-01', '2025-12-31'),
(2, 'Descuento por tarjeta de débito', 5.00, '2025-06-01', '2025-12-31'),
(3, 'Promoción de invierno', 15.00, '2025-07-01', '2025-08-31'),
(4, 'Cyber Monday', 20.00, '2025-11-04', '2025-11-06'),
(5, 'Descuento exclusivo para estudiantes', 12.50, '2025-06-01', '2025-09-30'),
(6, 'Descuento por transferencia bancaria', 7.00, '2025-06-01', '2025-12-31'),
(7, 'Sin descuento', 0.00, '2025-01-01', '2026-01-01');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `destinos`
--

CREATE TABLE `destinos` (
  `id_destino` int(11) NOT NULL,
  `ciudad` varchar(100) DEFAULT NULL,
  `pais` varchar(100) DEFAULT NULL,
  `descripcion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_pedido`
--

CREATE TABLE `detalle_pedido` (
  `id_detallepedido` int(11) NOT NULL,
  `id_pedido` int(11) DEFAULT NULL,
  `id_producto` int(11) DEFAULT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` decimal(10,2) DEFAULT 0.00,
  `total` decimal(10,2) NOT NULL,
  `id_estado` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `detalle_pedido`
--

INSERT INTO `detalle_pedido` (`id_detallepedido`, `id_pedido`, `id_producto`, `cantidad`, `precio_unitario`, `total`, `id_estado`) VALUES
(11, 3, 9, 1, 25000.00, 25000.00, 1),
(12, 3, 10, 1, 28000.00, 28000.00, 1),
(13, 3, 8, 1, 18000.00, 18000.00, 1),
(14, 4, 2, 1, 266000.00, 266000.00, 1),
(15, 4, 3, 1, 220000.00, 220000.00, 1),
(16, 4, 1, 1, 250000.00, 250000.00, 1),
(17, 5, 3, 1, 220000.00, 220000.00, 1),
(18, 5, 2, 1, 266000.00, 266000.00, 1),
(19, 6, 10, 1, 28000.00, 28000.00, 1),
(20, 7, 12, 2, 160000.00, 320000.00, 1),
(21, 7, 11, 1, 120000.00, 120000.00, 1),
(22, 8, 3, 1, 220000.00, 220000.00, 1),
(23, 9, 9, 2, 25000.00, 50000.00, 1),
(24, 10, 9, 1, 25000.00, 25000.00, 1),
(25, 11, 16, 1, 95000.00, 95000.00, 1),
(26, 12, 16, 1, 95000.00, 95000.00, 1),
(27, 13, 2, 1, 266000.00, 266000.00, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `email_resets`
--

CREATE TABLE `email_resets` (
  `id` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `nuevo_email` varchar(255) NOT NULL,
  `token` varchar(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `creado_en` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estadias`
--

CREATE TABLE `estadias` (
  `id_estadias` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `imagen` varchar(255) DEFAULT NULL,
  `imagen_interior` varchar(255) NOT NULL,
  `ubicacion` varchar(150) DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `id_producto` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `estadias`
--

INSERT INTO `estadias` (`id_estadias`, `nombre`, `imagen`, `imagen_interior`, `ubicacion`, `descripcion`, `precio`, `id_producto`) VALUES
(1, 'Alvear Palace Hotel', '../../SOURCE/RESOURCES/ESTADIAS/alvear-palace-hotel.jpg', '../../SOURCE/RESOURCES/ESTADIAS/alvear-palace-hotel-interior.webp', 'Buenos Aires', 'Un ícono de lujo en la ciudad, con spa, restaurantes gourmet y vistas a la Recoleta.', 120000.00, NULL),
(2, 'Llao Llao Hotel & Resort', '../../SOURCE/RESOURCES/ESTADIAS/hotel-llao-llao.jpg', '../../SOURCE/RESOURCES/ESTADIAS/hotel-llao-llao-interior.webp', 'Bariloche', 'Rodeado de lagos y montañas, ideal para escapadas románticas y actividades al aire libre.', 95000.00, NULL),
(3, 'Cavas Wine Lodge', '../../SOURCE/RESOURCES/ESTADIAS/cavas-wine-lodge.jpg', '../../SOURCE/RESOURCES/ESTADIAS/cavas-wine-lodge-interior.webp', 'Mendoza', 'Hotel boutique en viñedos, con spa, degustaciones y experiencias gourmet.', 110000.00, NULL),
(4, 'Hotel Faena', '../../SOURCE/RESOURCES/ESTADIAS/faena-hotel-interior.jpg', '../../SOURCE/RESOURCES/ESTADIAS/faena-hotel-interior.jpg', 'Buenos Aires', 'Lujo moderno en Puerto Madero, con piscina al aire libre y experiencias gastronómicas únicas.', 130000.00, NULL),
(5, 'Arakur Ushuaia Resort & Spa', '../../SOURCE/RESOURCES/ESTADIAS/arakur-hotel.jpg', '../../SOURCE/RESOURCES/ESTADIAS/Arakur-hotel-interior.webp', 'Ushuaia', 'Resort de montaña con vistas panorámicas al Canal Beagle y spa de primer nivel.', 115000.00, NULL),
(6, 'Hotel Amerian Portal del Iguazú', '../../SOURCE/RESOURCES/ESTADIAS/hotel-amerian.jpg', '../../SOURCE/RESOURCES/ESTADIAS/hotel-amerian-interior.avif', 'Misiones', 'A pasos de las Cataratas, ideal para familias y amantes de la naturaleza.', 80000.00, NULL),
(7, 'Ritz Paris', '../../SOURCE/RESOURCES/ESTADIAS/Hôtel_Ritz.jpg', '../../SOURCE/RESOURCES/ESTADIAS/hotel-ritz-interior.jpg', 'París, Francia', 'Elegancia y tradición en el corazón de París, con spa, restaurantes y suites de lujo.', 1000000.00, NULL),
(8, 'Burj Al Arab', '../../SOURCE/RESOURCES/ESTADIAS/burjalarab-dubai.webp', '../../SOURCE/RESOURCES/ESTADIAS/burjalarab-interior.webp', 'Dubái, Emiratos Árabes Unidos', 'El hotel más lujoso del mundo, con suites exclusivas y servicio de mayordomo 24 hs.', 1200000.00, NULL),
(9, 'Marina Bay Sands', '../../SOURCE/RESOURCES/ESTADIAS/marina-bay.webp', '../../SOURCE/RESOURCES/ESTADIAS/marina-bay-interior.avif', 'Singapur', 'Famoso por su piscina infinita en la azotea y vistas panorámicas de la ciudad.', 600000.00, NULL),
(10, 'The Plaza Hotel', '../../SOURCE/RESOURCES/ESTADIAS/luxury-hotel.webp', '../../SOURCE/RESOURCES/ESTADIAS/hotel-plaza-interior.jpeg', 'Nueva York, EE.UU.', 'Histórico hotel de lujo frente a Central Park, símbolo de elegancia neoyorquina.', 900000.00, NULL),
(11, 'Hotel Atlantis The Palm', '../../SOURCE/RESOURCES/ESTADIAS/atlantis.jpeg', '../../SOURCE/RESOURCES/ESTADIAS/atlantis-interior.jpg', 'Dubái, Emiratos Árabes Unidos', 'Resort icónico en la isla Palm Jumeirah, con parque acuático y acuario.', 700000.00, NULL),
(12, 'Hotel Bellagio', '../../SOURCE/RESOURCES/ESTADIAS/bellagio-hotel.jpg', '../../SOURCE/RESOURCES/ESTADIAS/bellagio-interior.png', 'Las Vegas, EE.UU.', 'Famoso por su espectáculo de fuentes y casino, en el corazón del Strip.', 400000.00, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `estado_pedido`
--

CREATE TABLE `estado_pedido` (
  `id_estado` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `estado_pedido`
--

INSERT INTO `estado_pedido` (`id_estado`, `nombre`) VALUES
(1, 'Pendiente'),
(2, 'Finalizado');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `facturacion`
--

CREATE TABLE `facturacion` (
  `id_factura` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `dni_cuil` varchar(20) DEFAULT NULL,
  `razon_social` varchar(100) DEFAULT NULL,
  `direccion_fiscal` varchar(200) DEFAULT NULL,
  `condicion_iva` enum('Responsable Inscripto','Monotributista','Consumidor Final') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `localidad`
--

CREATE TABLE `localidad` (
  `id_localidad` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `id_partido` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `opiniones`
--

CREATE TABLE `opiniones` (
  `id_opinion` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `opinion` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `opiniones`
--

INSERT INTO `opiniones` (`id_opinion`, `id_usuario`, `opinion`) VALUES
(1, 39, 'buena pagina');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pagometodo`
--

CREATE TABLE `pagometodo` (
  `id_pagometodo` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `id_descuento` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `pagometodo`
--

INSERT INTO `pagometodo` (`id_pagometodo`, `nombre`, `id_descuento`) VALUES
(1, 'credito', NULL),
(2, 'debito', NULL),
(3, 'efectivo', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `paquetes`
--

CREATE TABLE `paquetes` (
  `id_paquetes` int(11) NOT NULL,
  `nombre_viaje` varchar(100) NOT NULL,
  `imagen` varchar(255) DEFAULT NULL,
  `duracion` varchar(50) DEFAULT NULL,
  `incluye` text DEFAULT NULL,
  `precio_aprox` decimal(10,2) DEFAULT NULL,
  `id_producto` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `paquetes`
--

INSERT INTO `paquetes` (`id_paquetes`, `nombre_viaje`, `imagen`, `duracion`, `incluye`, `precio_aprox`, `id_producto`) VALUES
(1, 'Bariloche - Villa La Angostura', '../../SOURCE/RESOURCES/bariloche.jpeg', '5 días / 4 noches', 'Vuelo, hotel 4 estrellas, traslados, excursiones opcionales.', 250000.00, NULL),
(3, 'Cataratas del Iguazú - Puerto Iguazú', '../../SOURCE/RESOURCES/iguazu.jpeg', '4 días / 3 noches', 'Vuelo, alojamiento, visitas guiadas a las cataratas.', 266000.00, NULL),
(4, 'Mendoza - Valle de Uco', '../../SOURCE/RESOURCES/valle-de-uco.webp', ' 4 días / 3 noches', ' Vuelo, hotel, tours de bodegas y degustaciones.', 220000.00, NULL),
(5, 'Buenos Aires - Tigre Delta', '../../SOURCE/RESOURCES/tigre-delta.jpg', '4 dias / 5 noches', 'Hotel, city tour, paseo por el delta.', 120000.00, NULL),
(6, 'El Calafate - Glaciar Perito Moreno', '../../SOURCE/RESOURCES/atractivo-glaciar-perito-moreno-1.jpg', '4 días / 3 noches', 'Vuelos, hotel, excursión al glaciar.', 350000.00, NULL),
(7, 'Buenos Aires - Mar del Plata', '../../SOURCE/RESOURCES/mar-del-plata.jpg', '5 días / 4 noches', 'Bus semicama, hotel frente al mar, desayuno incluido, city tour.', 270000.00, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `partido`
--

CREATE TABLE `partido` (
  `id_partido` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `id_provincia` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pasajeros`
--

CREATE TABLE `pasajeros` (
  `id_pasajero` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `apellido` varchar(50) NOT NULL,
  `dni` varchar(20) NOT NULL,
  `fecha_nacimiento` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pasajes`
--

CREATE TABLE `pasajes` (
  `id_pasajes` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `imagen` varchar(255) DEFAULT NULL,
  `aerolinea` varchar(100) DEFAULT NULL,
  `duracion` varchar(50) DEFAULT NULL,
  `precio_desde` decimal(10,2) DEFAULT NULL,
  `clase` varchar(50) DEFAULT NULL,
  `id_producto` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `pasajes`
--

INSERT INTO `pasajes` (`id_pasajes`, `nombre`, `imagen`, `aerolinea`, `duracion`, `precio_desde`, `clase`, `id_producto`) VALUES
(1, 'BUENOS AIRES → BARILOCHE', '../../SOURCE/RESOURCES/PASAJES/bariloche.png', 'Aerolíneas Argentinas', '2h 20m', 65000.00, 'Económica / Ejecutiva', NULL),
(2, 'CÓRDOBA → MENDOZA', '../../SOURCE/RESOURCES/PASAJES/cordoba.jpg', 'Flybondi', '1h 30m', 48000.00, 'Económica', NULL),
(3, 'BUENOS AIRES → USHUAIA', '../../SOURCE/RESOURCES/PASAJES/ushuaia.webp', 'JetSMART', '3h 30m', 80000.00, 'Económica', NULL),
(4, 'BUENOS AIRES → MADRID', '../../SOURCE/RESOURCES/PASAJES/madrid.jpg', 'Iberia', '12h 30m', 950.00, 'Económica / Ejecutiva', NULL),
(5, 'BUENOS AIRES → MIAMI', '../../SOURCE/RESOURCES/PASAJES/miami.webp', 'American Airlines', '9h 0m', 800.00, 'Económica / Ejecutiva', NULL),
(6, 'BUENOS AIRES → PARÍS', '../../SOURCE/RESOURCES/PASAJES/paris.webp', 'Air France', '13h 0m', 1050.00, 'Económica / Ejecutiva', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `token` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `password_resets`
--

INSERT INTO `password_resets` (`id`, `id_usuario`, `token`, `expires_at`, `creado_en`) VALUES
(6, 39, '115ce7ff51012a1a8f518a0104258a6a467b1f96235a2d40394bf77c8cd39b76', '2025-06-26 21:21:24', '2025-06-26 18:21:24'),
(8, 39, '48eb7c7fdbc3c03e5ff2eb05a6942e8d2b61a6d7030f4d8481f88f9e18789fd5', '2025-06-26 22:18:32', '2025-06-26 19:18:32');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedido`
--

CREATE TABLE `pedido` (
  `id_pedido` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `id_pagometodo` int(11) DEFAULT NULL,
  `id_descuento` int(11) DEFAULT NULL,
  `total` decimal(10,2) DEFAULT 0.00,
  `fecha` datetime DEFAULT current_timestamp(),
  `nombre` varchar(100) DEFAULT NULL,
  `apellido` varchar(100) DEFAULT NULL,
  `dni` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `pedido`
--

INSERT INTO `pedido` (`id_pedido`, `id_usuario`, `id_pagometodo`, `id_descuento`, `total`, `fecha`, `nombre`, `apellido`, `dni`) VALUES
(1, 39, 1, NULL, NULL, '2025-06-26 01:36:57', 'Lautaro', 'Souza', '47941303'),
(2, 39, 1, NULL, 901000.00, '2025-06-26 03:27:46', 'asdadasd', 'dasd', '23232323'),
(3, 39, 1, NULL, 71000.00, '2025-06-26 04:25:42', 'asdadasd', 'asdasdasd', '47941303'),
(4, 39, 1, NULL, 736000.00, '2025-06-26 04:32:18', 'Lautaro', 'Souza', '47941303'),
(5, 39, 1, NULL, 486000.00, '2025-06-26 04:47:20', 'Lautaro', 'asdasdasd', '47941303'),
(6, 39, 1, NULL, 28000.00, '2025-06-26 04:48:00', 'Lautaro', 'Souza', '47941303'),
(7, 39, 1, NULL, 440000.00, '2025-06-26 04:58:20', 'Lautaro', 'Souza', '47941303'),
(8, 39, 3, NULL, 220000.00, '2025-06-26 05:00:58', 'Lautaro', 'Souza', '23232356'),
(9, 39, 1, NULL, 50000.00, '2025-06-26 05:11:10', 'Lautaro', 'Souza', '23232323'),
(10, 39, 1, NULL, 25000.00, '2025-06-26 05:12:45', 'asdadasd', 'Souza', '23232323'),
(11, 39, 1, NULL, 95000.00, '2025-06-26 05:15:14', 'Lautaro', 'dasddwada', '23232356'),
(12, 39, 1, NULL, 95000.00, '2025-06-26 05:22:01', 'dasdsadas', 'asdasdasd', '47941303'),
(13, 39, 1, NULL, 266000.00, '2025-06-26 05:25:08', 'Lautaro', 'asdasdasd', '23232323');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` int(11) NOT NULL,
  `tipo` enum('auto','estadia','paquete','pasaje') NOT NULL,
  `id_referencia` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `tipo`, `id_referencia`) VALUES
(1, 'paquete', 1),
(2, 'paquete', 3),
(3, 'paquete', 4),
(4, 'paquete', 5),
(5, 'paquete', 6),
(6, 'paquete', 7),
(8, 'auto', 1),
(9, 'auto', 3),
(10, 'auto', 4),
(11, 'auto', 5),
(12, 'auto', 6),
(15, 'estadia', 1),
(16, 'estadia', 2),
(17, 'estadia', 3),
(18, 'estadia', 4),
(19, 'estadia', 5),
(20, 'estadia', 6),
(21, 'estadia', 7),
(22, 'estadia', 8),
(23, 'estadia', 9),
(24, 'estadia', 10),
(25, 'estadia', 11),
(26, 'estadia', 12),
(30, 'pasaje', 1),
(31, 'pasaje', 2),
(32, 'pasaje', 3),
(33, 'pasaje', 4),
(34, 'pasaje', 5),
(35, 'pasaje', 6),
(37, 'paquete', 6),
(38, 'paquete', 5),
(39, 'auto', 3),
(40, 'pasaje', 1),
(41, 'pasaje', 2);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `provincia`
--

CREATE TABLE `provincia` (
  `id_provincia` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `reservas`
--

CREATE TABLE `reservas` (
  `id_reserva` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `id_paquete` int(11) DEFAULT NULL,
  `fecha_reserva` date DEFAULT NULL,
  `cantidad_personas` int(11) DEFAULT NULL,
  `estado` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `rol`
--

CREATE TABLE `rol` (
  `id_rol` int(11) NOT NULL,
  `rol` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tarjeta`
--

CREATE TABLE `tarjeta` (
  `id_tarjeta` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `numero` varchar(20) NOT NULL,
  `nombre_tarjeta` varchar(100) DEFAULT NULL,
  `vencimiento` date DEFAULT NULL,
  `codigo_seguridad` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tarjeta`
--

INSERT INTO `tarjeta` (`id_tarjeta`, `id_usuario`, `numero`, `nombre_tarjeta`, `vencimiento`, `codigo_seguridad`) VALUES
(1, 39, '1234 5678 9101 1121', 'Souza lautaro benjamin', '2026-05-01', '212');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `transportes`
--

CREATE TABLE `transportes` (
  `id_transporte` int(11) NOT NULL,
  `tipo` varchar(50) DEFAULT NULL,
  `empresa` varchar(100) DEFAULT NULL,
  `descripcion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios`
--

CREATE TABLE `usuarios` (
  `id_usuario` int(11) NOT NULL,
  `usuario_nombre` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `contraseña` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `id_rol` int(11) DEFAULT NULL,
  `id_dato` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `usuario_nombre`, `email`, `contraseña`, `id_rol`, `id_dato`) VALUES
(39, 'Hooooooz', 'cuentag4x@gmail.com', '$2y$10$0wBks12fU4fyLhs7Xc.8NuDZ/Uxa9cM9OzWCRVB6ZMLH3VT6WTqGW', NULL, NULL),
(40, 'Hola', 'lautarobenjaminsouza@gmail.com', '$2y$10$icZPr7PAXihKx2Y7cd.4deTY.QG0lZT1o055Q4wfR46VZQBpBYt.C', NULL, NULL),
(41, 'dsadsadsad', 'lautarobenjaminsouz23232a@gmail.com', '$2y$10$x0fzivN4VhblfFRfwFzgWexfD89gmpW0Vyp7EU6K17.Xa7XB.QJye', NULL, NULL),
(42, 'Hoooooozhgyt', 'cuentag54r5644x@gmail.com', '$2y$10$QwuM8xYRsC/YYmBU9k7HFuQdLPXXZznpnO79abz2n1sCbM1/TMW5q', NULL, NULL),
(43, 'Hoooooozhgyt', 'safarakir232155135i@gmail.com', '$2y$10$G4EXISm/qTYl1tjY65yYTeHM1OyaciDh6SxlT7CNHPiegVH7s9rVm', NULL, NULL);

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `acciones_admins`
--
ALTER TABLE `acciones_admins`
  ADD PRIMARY KEY (`id_accion`),
  ADD KEY `id_admin` (`id_admin`);

--
-- Indices de la tabla `admins`
--
ALTER TABLE `admins`
  ADD PRIMARY KEY (`id_admin`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indices de la tabla `alojamientos`
--
ALTER TABLE `alojamientos`
  ADD PRIMARY KEY (`id_alojamiento`);

--
-- Indices de la tabla `autos`
--
ALTER TABLE `autos`
  ADD PRIMARY KEY (`id_autos`);

--
-- Indices de la tabla `carrito`
--
ALTER TABLE `carrito`
  ADD PRIMARY KEY (`id_carrito`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `carrito_items`
--
ALTER TABLE `carrito_items`
  ADD PRIMARY KEY (`id_item`),
  ADD KEY `id_carrito` (`id_carrito`),
  ADD KEY `fk_carrito_items_producto` (`id_producto`);

--
-- Indices de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD PRIMARY KEY (`id_dato`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_pasajero` (`id_pasajero`),
  ADD KEY `fk_localidad` (`id_localidad`);

--
-- Indices de la tabla `descuento`
--
ALTER TABLE `descuento`
  ADD PRIMARY KEY (`id_descuento`);

--
-- Indices de la tabla `destinos`
--
ALTER TABLE `destinos`
  ADD PRIMARY KEY (`id_destino`);

--
-- Indices de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  ADD PRIMARY KEY (`id_detallepedido`),
  ADD KEY `fk_detalle_pedido_pedido` (`id_pedido`),
  ADD KEY `fk_detalle_pedido_producto` (`id_producto`),
  ADD KEY `fk_detalle_pedido_estado` (`id_estado`);

--
-- Indices de la tabla `email_resets`
--
ALTER TABLE `email_resets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`);

--
-- Indices de la tabla `estadias`
--
ALTER TABLE `estadias`
  ADD PRIMARY KEY (`id_estadias`);

--
-- Indices de la tabla `estado_pedido`
--
ALTER TABLE `estado_pedido`
  ADD PRIMARY KEY (`id_estado`);

--
-- Indices de la tabla `facturacion`
--
ALTER TABLE `facturacion`
  ADD PRIMARY KEY (`id_factura`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `localidad`
--
ALTER TABLE `localidad`
  ADD PRIMARY KEY (`id_localidad`),
  ADD KEY `id_partido` (`id_partido`);

--
-- Indices de la tabla `opiniones`
--
ALTER TABLE `opiniones`
  ADD PRIMARY KEY (`id_opinion`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `pagometodo`
--
ALTER TABLE `pagometodo`
  ADD PRIMARY KEY (`id_pagometodo`),
  ADD KEY `fk_orden_descuento` (`id_descuento`);

--
-- Indices de la tabla `paquetes`
--
ALTER TABLE `paquetes`
  ADD PRIMARY KEY (`id_paquetes`);

--
-- Indices de la tabla `partido`
--
ALTER TABLE `partido`
  ADD PRIMARY KEY (`id_partido`),
  ADD KEY `id_provincia` (`id_provincia`);

--
-- Indices de la tabla `pasajeros`
--
ALTER TABLE `pasajeros`
  ADD PRIMARY KEY (`id_pasajero`),
  ADD UNIQUE KEY `dni` (`dni`);

--
-- Indices de la tabla `pasajes`
--
ALTER TABLE `pasajes`
  ADD PRIMARY KEY (`id_pasajes`);

--
-- Indices de la tabla `password_resets`
--
ALTER TABLE `password_resets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `pedido`
--
ALTER TABLE `pedido`
  ADD PRIMARY KEY (`id_pedido`),
  ADD KEY `fk_pedido_pagometodo` (`id_pagometodo`),
  ADD KEY `fk_pedido_descuento` (`id_descuento`),
  ADD KEY `idx_pedido_id_usuario` (`id_usuario`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`);

--
-- Indices de la tabla `provincia`
--
ALTER TABLE `provincia`
  ADD PRIMARY KEY (`id_provincia`);

--
-- Indices de la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD PRIMARY KEY (`id_reserva`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_paquete` (`id_paquete`);

--
-- Indices de la tabla `rol`
--
ALTER TABLE `rol`
  ADD PRIMARY KEY (`id_rol`),
  ADD UNIQUE KEY `rol` (`rol`);

--
-- Indices de la tabla `tarjeta`
--
ALTER TABLE `tarjeta`
  ADD PRIMARY KEY (`id_tarjeta`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `transportes`
--
ALTER TABLE `transportes`
  ADD PRIMARY KEY (`id_transporte`);

--
-- Indices de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD PRIMARY KEY (`id_usuario`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `fk_rol` (`id_rol`),
  ADD KEY `fk_datos_personales` (`id_dato`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `acciones_admins`
--
ALTER TABLE `acciones_admins`
  MODIFY `id_accion` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `admins`
--
ALTER TABLE `admins`
  MODIFY `id_admin` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `alojamientos`
--
ALTER TABLE `alojamientos`
  MODIFY `id_alojamiento` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `autos`
--
ALTER TABLE `autos`
  MODIFY `id_autos` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `carrito`
--
ALTER TABLE `carrito`
  MODIFY `id_carrito` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT de la tabla `carrito_items`
--
ALTER TABLE `carrito_items`
  MODIFY `id_item` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=33;

--
-- AUTO_INCREMENT de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  MODIFY `id_dato` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `descuento`
--
ALTER TABLE `descuento`
  MODIFY `id_descuento` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `destinos`
--
ALTER TABLE `destinos`
  MODIFY `id_destino` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  MODIFY `id_detallepedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT de la tabla `email_resets`
--
ALTER TABLE `email_resets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `estadias`
--
ALTER TABLE `estadias`
  MODIFY `id_estadias` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT de la tabla `estado_pedido`
--
ALTER TABLE `estado_pedido`
  MODIFY `id_estado` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `facturacion`
--
ALTER TABLE `facturacion`
  MODIFY `id_factura` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `localidad`
--
ALTER TABLE `localidad`
  MODIFY `id_localidad` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `opiniones`
--
ALTER TABLE `opiniones`
  MODIFY `id_opinion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `pagometodo`
--
ALTER TABLE `pagometodo`
  MODIFY `id_pagometodo` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `paquetes`
--
ALTER TABLE `paquetes`
  MODIFY `id_paquetes` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `partido`
--
ALTER TABLE `partido`
  MODIFY `id_partido` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `pasajeros`
--
ALTER TABLE `pasajeros`
  MODIFY `id_pasajero` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `pasajes`
--
ALTER TABLE `pasajes`
  MODIFY `id_pasajes` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT de la tabla `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `pedido`
--
ALTER TABLE `pedido`
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- AUTO_INCREMENT de la tabla `provincia`
--
ALTER TABLE `provincia`
  MODIFY `id_provincia` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `reservas`
--
ALTER TABLE `reservas`
  MODIFY `id_reserva` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `rol`
--
ALTER TABLE `rol`
  MODIFY `id_rol` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `tarjeta`
--
ALTER TABLE `tarjeta`
  MODIFY `id_tarjeta` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `transportes`
--
ALTER TABLE `transportes`
  MODIFY `id_transporte` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `acciones_admins`
--
ALTER TABLE `acciones_admins`
  ADD CONSTRAINT `acciones_admins_ibfk_1` FOREIGN KEY (`id_admin`) REFERENCES `admins` (`id_admin`);

--
-- Filtros para la tabla `carrito`
--
ALTER TABLE `carrito`
  ADD CONSTRAINT `carrito_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Filtros para la tabla `carrito_items`
--
ALTER TABLE `carrito_items`
  ADD CONSTRAINT `carrito_items_ibfk_1` FOREIGN KEY (`id_carrito`) REFERENCES `carrito` (`id_carrito`),
  ADD CONSTRAINT `fk_carrito_items_producto` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_id_producto` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE;

--
-- Filtros para la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD CONSTRAINT `datos_personales_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE,
  ADD CONSTRAINT `datos_personales_ibfk_2` FOREIGN KEY (`id_pasajero`) REFERENCES `pasajeros` (`id_pasajero`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_localidad` FOREIGN KEY (`id_localidad`) REFERENCES `localidad` (`id_localidad`);

--
-- Filtros para la tabla `detalle_pedido`
--
ALTER TABLE `detalle_pedido`
  ADD CONSTRAINT `fk_detalle_pedido_estado` FOREIGN KEY (`id_estado`) REFERENCES `estado_pedido` (`id_estado`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_detalle_pedido_pedido` FOREIGN KEY (`id_pedido`) REFERENCES `pedido` (`id_pedido`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_detalle_pedido_producto` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `facturacion`
--
ALTER TABLE `facturacion`
  ADD CONSTRAINT `facturacion_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `localidad`
--
ALTER TABLE `localidad`
  ADD CONSTRAINT `localidad_ibfk_1` FOREIGN KEY (`id_partido`) REFERENCES `partido` (`id_partido`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `opiniones`
--
ALTER TABLE `opiniones`
  ADD CONSTRAINT `opiniones_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `pagometodo`
--
ALTER TABLE `pagometodo`
  ADD CONSTRAINT `fk_orden_descuento` FOREIGN KEY (`id_descuento`) REFERENCES `descuento` (`id_descuento`);

--
-- Filtros para la tabla `partido`
--
ALTER TABLE `partido`
  ADD CONSTRAINT `partido_ibfk_1` FOREIGN KEY (`id_provincia`) REFERENCES `provincia` (`id_provincia`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `password_resets`
--
ALTER TABLE `password_resets`
  ADD CONSTRAINT `password_resets_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `pedido`
--
ALTER TABLE `pedido`
  ADD CONSTRAINT `fk_pedido_descuento` FOREIGN KEY (`id_descuento`) REFERENCES `descuento` (`id_descuento`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_pedido_pagometodo` FOREIGN KEY (`id_pagometodo`) REFERENCES `pagometodo` (`id_pagometodo`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_pedido_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD CONSTRAINT `reservas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

--
-- Filtros para la tabla `tarjeta`
--
ALTER TABLE `tarjeta`
  ADD CONSTRAINT `tarjeta_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `usuarios`
--
ALTER TABLE `usuarios`
  ADD CONSTRAINT `fk_datos_personales` FOREIGN KEY (`id_dato`) REFERENCES `datos_personales` (`id_dato`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_rol` FOREIGN KEY (`id_rol`) REFERENCES `rol` (`id_rol`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
