-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 30-06-2025 a las 09:24:10
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPBringEmail` (IN `sp_email` VARCHAR(255))   BEGIN
    SELECT COUNT(*) AS count_email FROM usuarios WHERE email = sp_email COLLATE utf8mb4_unicode_ci;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPBringPassword` (IN `p_email` VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)   BEGIN
  SELECT contraseña FROM usuarios WHERE email COLLATE utf8mb4_unicode_ci = p_email COLLATE utf8mb4_unicode_ci;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPBringVerificationStatus` (IN `sp_email` VARCHAR(255))   BEGIN
    SELECT 
        CASE 
            WHEN u.id_verify = 1 THEN TRUE
            WHEN u.id_verify = 2 THEN FALSE
            WHEN u.id_verify IS NULL THEN NULL
            ELSE NULL
        END AS verificado
    FROM usuarios u
    WHERE u.email = sp_email COLLATE utf8mb4_unicode_ci
    LIMIT 1;
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPRegistrarUsuario` (IN `p_user` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_password` VARCHAR(255), IN `p_rol` INT)   BEGIN
    INSERT INTO usuarios (usuario_nombre, email, contraseña, id_rol)
    VALUES (p_user, p_email, p_password, p_rol);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPResetEmail` (IN `p_token` VARCHAR(255), IN `p_new_email` VARCHAR(255))   BEGIN
    DECLARE v_id_usuario INT;

    -- Obtener el ID del usuario con ese token
    SELECT id_usuario INTO v_id_usuario
    FROM email_resets
    WHERE token COLLATE utf8mb4_unicode_ci = p_token COLLATE utf8mb4_unicode_ci
    LIMIT 1;

    -- Verificar si se encontró un usuario
    IF v_id_usuario IS NOT NULL THEN

        -- Actualizar el email del usuario
        UPDATE usuarios
        SET email = p_new_email
        WHERE id_usuario = v_id_usuario;

        -- Eliminar el token
        DELETE FROM email_resets
        WHERE token COLLATE utf8mb4_unicode_ci = p_token COLLATE utf8mb4_unicode_ci;

    END IF;
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPSetUsuarioVerificado` (IN `sp_id_usuario` INT, IN `sp_verificado` BOOLEAN)   BEGIN
    UPDATE usuarios
    SET id_verify = IF(sp_verificado, 1, 2)
    WHERE id_usuario = sp_id_usuario;
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPVaciarEmailResets` ()   BEGIN
    DELETE FROM email_resets;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPVaciarPassResets` ()   BEGIN
    DELETE FROM password_resets;
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
  `id_usuario` int(11) NOT NULL
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
(25, 39, '2025-06-26 05:24:58', 'comprado'),
(26, 47, '2025-06-29 22:32:03', 'comprado'),
(27, 47, '2025-06-29 23:19:34', 'activo');

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

--
-- Volcado de datos para la tabla `carrito_items`
--

INSERT INTO `carrito_items` (`id_item`, `id_carrito`, `tipo`, `cantidad`, `id_producto`) VALUES
(35, 27, 'paquete', 1, 2),
(36, 27, 'auto', 1, 9);

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
  `id_localidad` int(11) DEFAULT NULL,
  `codigo_postal` varchar(8) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `datos_personales`
--

INSERT INTO `datos_personales` (`id_dato`, `id_usuario`, `nombre`, `apellido`, `fecha_nacimiento`, `sexo`, `telefono`, `id_pasajero`, `dni`, `id_localidad`, `codigo_postal`) VALUES
(2, 47, 'Lautaro', 'Souza', '2007-05-20', 'Masculino', '541161623274', NULL, '', NULL, NULL);

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
(27, 13, 2, 1, 266000.00, 266000.00, 1),
(28, 14, 8, 12, 18000.00, 216000.00, 1);

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

--
-- Volcado de datos para la tabla `email_resets`
--

INSERT INTO `email_resets` (`id`, `id_usuario`, `nuevo_email`, `token`, `expires_at`, `creado_en`) VALUES
(9, 47, 'safarakiri@gmail.com', 'd6259b69c5dc6f23d625c9145ac248af6c29b3cb88c78f6dca3a85d166931e5e', '2025-06-30 08:41:17', '2025-06-30 02:41:17');

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

--
-- Volcado de datos para la tabla `localidad`
--

INSERT INTO `localidad` (`id_localidad`, `nombre`, `id_partido`) VALUES
(2014010, 'Ciudad de Buenos Aires', 2014),
(6007010, 'Carhué', 6007),
(6007020, 'Colonia San Miguel Arcángel', 6007),
(6007030, 'Delfín Huergo', 6007),
(6007040, 'Espartillar', 6007),
(6007050, 'Esteban Agustín Gascón', 6007),
(6007060, 'La Pala', 6007),
(6007070, 'Maza', 6007),
(6007080, 'Rivera', 6007),
(6007100, 'Villa Margarita', 6007),
(6014010, 'Adolfo Gonzales Chaves', 6014),
(6014020, 'De La Garma', 6014),
(6014030, 'Juan E. Barra', 6014),
(6014040, 'Vásquez', 6014),
(6021010, 'Alberti', 6021),
(6021020, 'Coronel Seguí', 6021),
(6021030, 'Mechita', 6021),
(6021040, 'Pla', 6021),
(6021050, 'Villa Grisolía', 6021),
(6021060, 'Villa María', 6021),
(6021070, 'Villa Ortiz', 6021),
(6028010, 'Almirante Brown', 6028),
(6035010, 'Avellaneda', 6035),
(6042010, 'Ayacucho', 6042),
(6042020, 'La Constancia', 6042),
(6042030, 'Solanet', 6042),
(6042040, 'Udaquiola', 6042),
(6049010, 'Ariel', 6049),
(6049020, 'Azul', 6049),
(6049030, 'Cacharí', 6049),
(6049040, 'Chillar', 6049),
(6049050, '16 de Julio', 6049),
(6056010, 'Bahía Blanca', 6056),
(6056020, 'Cabildo', 6056),
(6056030, 'General Daniel Cerri', 6056),
(6063010, 'Balcarce', 6063),
(6063020, 'Los Pinos', 6063),
(6063030, 'Napaleofú', 6063),
(6063040, 'Ramos Otero', 6063),
(6063050, 'San Agustín', 6063),
(6063060, 'Villa Laguna La Brava', 6063),
(6070010, 'Baradero', 6070),
(6070020, 'Irineo Portela', 6070),
(6070030, 'Santa Coloma', 6070),
(6070040, 'Villa Alsina', 6070),
(6077010, 'Arrecifes', 6077),
(6077020, 'Todd', 6077),
(6077030, 'Viña', 6077),
(6084010, 'Barker', 6084),
(6084020, 'Benito Juárez', 6084),
(6084030, 'López', 6084),
(6084040, 'Tedín Uriburu', 6084),
(6084050, 'Villa Cacique', 6084),
(6091010, 'Berazategui', 6091),
(6098010, 'Berisso', 6098),
(6105010, 'Hale', 6105),
(6105020, 'Juan F. Ibarra', 6105),
(6105040, 'Paula', 6105),
(6105050, 'Pirovano', 6105),
(6105060, 'San Carlos de Bolívar', 6105),
(6105070, 'Urdampilleta', 6105),
(6105080, 'Villa Lynch Pueyrredón', 6105),
(6112010, 'Bragado', 6112),
(6112020, 'Comodoro Py', 6112),
(6112030, 'General O\'Brien', 6112),
(6112040, 'Irala', 6112),
(6112050, 'La Limpia', 6112),
(6112060, 'Juan F. Salaberry', 6112),
(6112070, 'Mechita', 6112),
(6112080, 'Olascoaga', 6112),
(6112090, 'Warnes', 6112),
(6119010, 'Altamirano', 6119),
(6119020, 'Barrio Las Golondrinas', 6119),
(6119030, 'Barrio Los Bosquecitos', 6119),
(6119040, 'Barrio Parque Las Acacias', 6119),
(6119050, 'Coronel Brandsen', 6119),
(6119060, 'Gómez', 6119),
(6119070, 'Jeppener', 6119),
(6119080, 'Oliden', 6119),
(6119090, 'Samborombón', 6119),
(6126010, 'Los Cardales', 6126),
(6126020, 'Barrio Los Pioneros (Barrio Tavella)', 6126),
(6134010, 'Alejandro Petión', 6134),
(6134020, 'Barrio El Taladro', 6134),
(6134030, 'Cañuelas', 6134),
(6134040, 'Gobernador Udaondo', 6134),
(6134060, 'Santa Rosa', 6134),
(6134070, 'Uribelarrea', 6134),
(6134080, 'Vicente Casares', 6134),
(6140010, 'Capitán Sarmiento', 6140),
(6140020, 'La Luisa', 6140),
(6147010, 'Bellocq', 6147),
(6147020, 'Cadret', 6147),
(6147030, 'Carlos Casares', 6147),
(6147040, 'Colonia Mauricio', 6147),
(6147050, 'Hortensia', 6147),
(6147060, 'La Sofía', 6147),
(6147070, 'Mauricio Hirsch', 6147),
(6147080, 'Moctezuma', 6147),
(6147090, 'Ordoqui', 6147),
(6147100, 'Smith', 6147),
(6154010, 'Carlos Tejedor', 6154),
(6154020, 'Colonia Seré', 6154),
(6154030, 'Curarú', 6154),
(6154040, 'Timote', 6154),
(6154050, 'Tres Algarrobos', 6154),
(6161010, 'Carmen de Areco', 6161),
(6161020, 'Pueblo Gouin', 6161),
(6161030, 'Tres Sargentos', 6161),
(6168010, 'Castelli', 6168),
(6168020, 'Centro Guerrero', 6168),
(6168030, 'Cerro de la Gloria', 6168),
(6175010, 'Colón', 6175),
(6175020, 'Villa Manuel Pomar', 6175),
(6175030, 'Pearson', 6175),
(6175040, 'Sarasa', 6175),
(6182010, 'Bajo Hondo', 6182),
(6182020, 'Balneario Pehuen Co', 6182),
(6182030, 'Punta Alta', 6182),
(6182050, 'Villa General Arias', 6182),
(6189010, 'Aparicio', 6189),
(6189020, 'Marisol', 6189),
(6189030, 'Coronel Dorrego', 6189),
(6189040, 'El Perdido', 6189),
(6189050, 'Faro', 6189),
(6189060, 'Irene', 6189),
(6189070, 'Oriente', 6189),
(6189080, 'San Román', 6189),
(6196010, 'Coronel Pringles', 6196),
(6196020, 'El Divisorio', 6196),
(6196030, 'El Pensamiento', 6196),
(6196040, 'Indio Rico', 6196),
(6196050, 'Lartigau', 6196),
(6203010, 'Cascada', 6203),
(6203020, 'Coronel Suárez', 6203),
(6203030, 'Curamalal', 6203),
(6203040, 'D\'Orbigny', 6203),
(6203050, 'Huanguelén', 6203),
(6203060, 'Pasman', 6203),
(6203070, 'San José', 6203),
(6203080, 'Santa María', 6203),
(6203090, 'Santa Trinidad', 6203),
(6203100, 'Villa La Arcadia', 6203),
(6210010, 'Castilla', 6210),
(6210020, 'Chacabuco', 6210),
(6210030, 'Los Angeles', 6210),
(6210040, 'O\'Higgins', 6210),
(6210050, 'Rawson', 6210),
(6218010, 'Chascomús', 6218),
(6218030, 'Villa Parque Girado', 6218),
(6224010, 'Chivilcoy', 6224),
(6224020, 'Emilio Ayarza', 6224),
(6224030, 'Gorostiaga', 6224),
(6224040, 'La Rica', 6224),
(6224050, 'Moquehuá', 6224),
(6224060, 'Ramón Biaus', 6224),
(6224070, 'San Sebastián', 6224),
(6231010, 'Andant', 6231),
(6231020, 'Arboledas', 6231),
(6231030, 'Daireaux', 6231),
(6231040, 'La Larga', 6231),
(6231060, 'Salazar', 6231),
(6238010, 'Dolores', 6238),
(6238020, 'Sevigne', 6238),
(6245010, 'Ensenada', 6245),
(6252010, 'Escobar', 6252),
(6260010, 'Esteban Echeverría', 6260),
(6266010, 'Arroyo de la Cruz', 6266),
(6266050, 'Parada Orlando', 6266),
(6266060, 'Parada Robles - Pavón', 6266),
(6270010, 'Ezeiza', 6270),
(6274010, 'Florencio Varela', 6274),
(6277010, 'Blaquier', 6277),
(6277020, 'Florentino Ameghino', 6277),
(6277030, 'Porvenir', 6277),
(6280010, 'Comandante Nicanor Otamendi', 6280),
(6280020, 'Mar del Sur', 6280),
(6280030, 'Mechongué', 6280),
(6280040, 'Miramar', 6280),
(6287010, 'General Alvear', 6287),
(6294010, 'Arribeños', 6294),
(6294020, 'Ascensión', 6294),
(6294030, 'Estación Arenales', 6294),
(6294040, 'Ferré', 6294),
(6294050, 'General Arenales', 6294),
(6294060, 'La Angelita', 6294),
(6294070, 'La Trinidad', 6294),
(6301010, 'General Belgrano', 6301),
(6301020, 'Gorchs', 6301),
(6308010, 'General Guido', 6308),
(6308020, 'Labardén', 6308),
(6315010, 'General Juan Madariaga', 6315),
(6322010, 'General La Madrid', 6322),
(6322020, 'La Colina', 6322),
(6322030, 'Las Martinetas', 6322),
(6322040, 'Líbano', 6322),
(6322050, 'Pontaut', 6322),
(6329010, 'General Hornos', 6329),
(6329020, 'General Las Heras', 6329),
(6329030, 'La Choza', 6329),
(6329050, 'Plomer', 6329),
(6336020, 'General Lavalle', 6336),
(6343010, 'Barrio Río Salado', 6343),
(6343020, 'Loma Verde', 6343),
(6343030, 'Ranchos', 6343),
(6343040, 'Villanueva', 6343),
(6351010, 'Colonia San Ricardo', 6351),
(6351020, 'General Pinto', 6351),
(6351030, 'Germania', 6351),
(6351040, 'Villa Francia', 6351),
(6351050, 'Villa Roth', 6351),
(6357060, 'Barrio Santa Paula', 6357),
(6357070, 'Batán', 6357),
(6357080, 'Chapadmalal', 6357),
(6357090, 'El Marquesado', 6357),
(6357100, 'Estación Chapadmalal', 6357),
(6357110, 'Mar del Plata', 6357),
(6357120, 'Sierra de los Padres', 6357),
(6364030, 'General Rodríguez', 6364),
(6371010, 'General San Martín', 6371),
(6385010, 'Baigorrita', 6385),
(6385020, 'La Delfina', 6385),
(6385030, 'Los Toldos', 6385),
(6385040, 'San Emilio', 6385),
(6385050, 'Zavalía', 6385),
(6392010, 'Banderaló', 6392),
(6392020, 'Cañada Seca', 6392),
(6392030, 'Coronel Charlone', 6392),
(6392040, 'Emilio V. Bunge', 6392),
(6392050, 'General Villegas', 6392),
(6392060, 'Massey', 6392),
(6392070, 'Pichincha', 6392),
(6392080, 'Piedritas', 6392),
(6392090, 'Santa Eleodora', 6392),
(6392100, 'Santa Regina', 6392),
(6392110, 'Villa Saboya', 6392),
(6392120, 'Villa Sauze', 6392),
(6399010, 'Arroyo Venado', 6399),
(6399020, 'Casbas', 6399),
(6399030, 'Garré', 6399),
(6399040, 'Guaminí', 6399),
(6399050, 'Laguna Alsina', 6399),
(6406010, 'Henderson', 6406),
(6406020, 'Herrera Vegas', 6406),
(6408010, 'Hurlingham', 6408),
(6410010, 'Ituzaingó', 6410),
(6412010, 'José C. Paz', 6412),
(6413010, 'Agustín Roca', 6413),
(6413020, 'Agustina', 6413),
(6413030, 'Balneario Laguna de Gómez', 6413),
(6413040, 'Fortín Tiburcio', 6413),
(6413050, 'Junín', 6413),
(6413060, 'Laplacette', 6413),
(6413080, 'Saforcada', 6413),
(6420010, 'Las Toninas', 6420),
(6420020, 'Mar de Ajó - San Bernardo', 6420),
(6420030, 'San Clemente del Tuyú', 6420),
(6420040, 'Santa Teresita - Mar del Tuyú', 6420),
(6427010, 'La Matanza', 6427),
(6434010, 'Lanús', 6434),
(6441030, 'La Plata', 6441),
(6448010, 'Laprida', 6448),
(6448020, 'Pueblo Nuevo', 6448),
(6448030, 'Pueblo San Jorge', 6448),
(6455010, 'Coronel Boerr', 6455),
(6455020, 'El Trigo', 6455),
(6455030, 'Las Flores', 6455),
(6455040, 'Pardo', 6455),
(6462010, 'Alberdi Viejo', 6462),
(6462020, 'El Dorado', 6462),
(6462030, 'Fortín Acha', 6462),
(6462040, 'Juan Bautista Alberdi', 6462),
(6462050, 'Leandro N. Alem', 6462),
(6462060, 'Vedia', 6462),
(6466020, 'Manuel J. Cobo', 6466),
(6469010, 'Arenaza', 6469),
(6469020, 'Bayauca', 6469),
(6469030, 'Bermúdez', 6469),
(6469040, 'Carlos Salas', 6469),
(6469050, 'Coronel Martínez de Hoz', 6469),
(6469060, 'El Triunfo', 6469),
(6469070, 'Las Toscas', 6469),
(6469080, 'Lincoln', 6469),
(6469090, 'Pasteur', 6469),
(6469100, 'Roberts', 6469),
(6469110, 'Triunvirato', 6469),
(6476010, 'Arenas Verdes', 6476),
(6476020, 'Licenciado Matienzo', 6476),
(6476030, 'Lobería', 6476),
(6476040, 'Pieres', 6476),
(6476050, 'San Manuel', 6476),
(6476060, 'Tamangueyú', 6476),
(6483010, 'Antonio Carboni', 6483),
(6483020, 'Elvira', 6483),
(6483030, 'Laguna de Lobos', 6483),
(6483040, 'Lobos', 6483),
(6483050, 'Salvador María', 6483),
(6490010, 'Lomas de Zamora', 6490),
(6497020, 'Carlos Keen', 6497),
(6497060, 'Luján', 6497),
(6497070, 'Olivera', 6497),
(6497090, 'Torres', 6497),
(6505010, 'Atalaya', 6505),
(6505020, 'General Mansilla', 6505),
(6505030, 'Los Naranjos', 6505),
(6505040, 'Magdalena', 6505),
(6505050, 'Roberto J. Payró', 6505),
(6505060, 'Vieytes', 6505),
(6511010, 'Las Armas', 6511),
(6511020, 'Maipú', 6511),
(6511030, 'Santo Domingo', 6511),
(6515010, 'Malvinas Argentinas', 6515),
(6518010, 'Coronel Vidal', 6518),
(6518020, 'General Pirán', 6518),
(6518030, 'La Armonía', 6518),
(6518040, 'Mar Chiquita', 6518),
(6518050, 'Mar de Cobo', 6518),
(6518060, 'Santa Clara del Mar', 6518),
(6518070, 'Vivoratá', 6518),
(6525020, 'Marcos Paz', 6525),
(6532010, 'Gowland', 6532),
(6532020, 'Mercedes', 6532),
(6532030, 'Jorge Born', 6532),
(6539010, 'Merlo', 6539),
(6547010, 'Abbott', 6547),
(6547020, 'San Miguel del Monte', 6547),
(6547030, 'Zenón Videla Dorna', 6547),
(6553010, 'Balneario Sauce Grande', 6553),
(6553020, 'Monte Hermoso', 6553),
(6560010, 'Moreno', 6560),
(6568010, 'Morón', 6568),
(6574010, 'José Juan Almeyra', 6574),
(6574020, 'Las Marianas', 6574),
(6574030, 'Navarro', 6574),
(6574040, 'Villa Moll', 6574),
(6581010, 'Claraz', 6581),
(6581030, 'Juan N. Fernández', 6581),
(6581040, 'Necochea - Quequén', 6581),
(6581050, 'Nicanor Olivera', 6581),
(6581060, 'Ramón Santamarina', 6581),
(6588010, 'Alfredo Demarchi', 6588),
(6588020, 'Carlos María Naón', 6588),
(6588030, '12 de Octubre', 6588),
(6588040, 'Dudignac', 6588),
(6588050, 'La Aurora', 6588),
(6588060, 'Manuel B. Gonnet', 6588),
(6588070, 'Marcelino Ugarte', 6588),
(6588080, 'Morea', 6588),
(6588090, 'Norumbega', 6588),
(6588100, '9 de Julio', 6588),
(6588110, 'Patricios', 6588),
(6588120, 'Villa Fournier', 6588),
(6595040, 'Colonia San Miguel', 6595),
(6595050, 'Espigas', 6595),
(6595060, 'Hinojo', 6595),
(6595070, 'Olavarría', 6595),
(6595080, 'Recalde', 6595),
(6595090, 'Santa Luisa', 6595),
(6595100, 'Sierra Chica', 6595),
(6595110, 'Sierras Bayas', 6595),
(6595120, 'Villa Alfredo Fortabat', 6595),
(6595130, 'Villa La Serranía', 6595),
(6602010, 'Bahía San Blas', 6602),
(6602020, 'Cardenal Cagliero', 6602),
(6602030, 'Carmen de Patagones', 6602),
(6602040, 'José B. Casas', 6602),
(6602050, 'Juan A. Pradere', 6602),
(6602060, 'Stroeder', 6602),
(6602070, 'Villalonga', 6602),
(6609010, 'Capitán Castro', 6609),
(6609020, 'San Esteban', 6609),
(6609030, 'Francisco Madero', 6609),
(6609040, 'Juan José Paso', 6609),
(6609050, 'Magdala', 6609),
(6609060, 'Mones Cazón', 6609),
(6609070, 'Nueva Plata', 6609),
(6609080, 'Pehuajó', 6609),
(6609090, 'San Bernardo', 6609),
(6616010, 'Bocayuva', 6616),
(6616020, 'De Bary', 6616),
(6616030, 'Pellegrini', 6616),
(6623010, 'Acevedo', 6623),
(6623020, 'Fontezuela', 6623),
(6623030, 'Guerrico', 6623),
(6623040, 'Juan A. de la Peña', 6623),
(6623050, 'Juan Anchorena', 6623),
(6623060, 'La Violeta', 6623),
(6623070, 'Manuel Ocampo', 6623),
(6623080, 'Mariano Benítez', 6623),
(6623090, 'Mariano H. Alfonzo', 6623),
(6623100, 'Pergamino', 6623),
(6623110, 'Pinzón', 6623),
(6623120, 'Rancagua', 6623),
(6623130, 'Villa Angélica', 6623),
(6623140, 'Villa San José', 6623),
(6630010, 'Casalins', 6630),
(6630020, 'Pila', 6630),
(6638040, 'Pilar', 6638),
(6644010, 'Pinamar', 6644),
(6648010, 'Presidente Perón', 6648),
(6651010, 'Azopardo', 6651),
(6651020, 'Bordenave', 6651),
(6651030, 'Darregueira', 6651),
(6651040, '17 de Agosto', 6651),
(6651050, 'Estela', 6651),
(6651060, 'Felipe Solá', 6651),
(6651070, 'López Lecube', 6651),
(6651080, 'Puán', 6651),
(6651090, 'San Germán', 6651),
(6651100, 'Villa Castelar', 6651),
(6651110, 'Villa Iris', 6651),
(6655010, 'Alvarez Jonte', 6655),
(6655030, 'Pipinas', 6655),
(6655040, 'Punta Indio', 6655),
(6655050, 'Verónica', 6655),
(6658010, 'Quilmes', 6658),
(6665010, 'El Paraíso', 6665),
(6665020, 'Las Bahamas', 6665),
(6665030, 'Pérez Millán', 6665),
(6665040, 'Ramallo', 6665),
(6665050, 'Villa General Savio', 6665),
(6665060, 'Villa Ramallo', 6665),
(6672010, 'Rauch', 6672),
(6679010, 'América', 6679),
(6679020, 'Fortín Olavarría', 6679),
(6679030, 'González Moreno', 6679),
(6679040, 'Mira Pampa', 6679),
(6679050, 'Roosevelt', 6679),
(6679060, 'San Mauricio', 6679),
(6679070, 'Sansinena', 6679),
(6679080, 'Sundblad', 6679),
(6686010, 'La Beba', 6686),
(6686020, 'Las Carabelas', 6686),
(6686030, 'Los Indios', 6686),
(6686040, 'Rafael Obligado', 6686),
(6686050, 'Roberto Cano', 6686),
(6686060, 'Rojas', 6686),
(6686070, 'Sol de Mayo', 6686),
(6686080, 'Villa Manuel Pomar', 6686),
(6693010, 'Carlos Beguerie', 6693),
(6693020, 'Roque Pérez', 6693),
(6700010, 'Arroyo Corto', 6700),
(6700020, 'Colonia San Martín', 6700),
(6700030, 'Dufaur', 6700),
(6700040, 'Espartillar', 6700),
(6700050, 'Goyena', 6700),
(6700060, 'Pigüé', 6700),
(6700070, 'Saavedra', 6700),
(6707010, 'Álvarez de Toledo', 6707),
(6707030, 'Cazón', 6707),
(6707040, 'Del Carril', 6707),
(6707050, 'Polvaredas', 6707),
(6714010, 'Arroyo Dulce', 6714),
(6714020, 'Berdier', 6714),
(6714030, 'Gahan', 6714),
(6714040, 'Inés Indart', 6714),
(6714050, 'La Invencible', 6714),
(6714060, 'Salto', 6714),
(6721010, 'Quenumá', 6721),
(6721020, 'Salliqueló', 6721),
(6728010, 'Azcuénaga', 6728),
(6728020, 'Cucullú', 6728),
(6728030, 'Franklin', 6728),
(6728040, 'San Andrés de Giles', 6728),
(6728050, 'Solís', 6728),
(6728060, 'Villa Espil', 6728),
(6728070, 'Villa Ruiz', 6728),
(6735010, 'Duggan', 6735),
(6735020, 'San Antonio de Areco', 6735),
(6735030, 'Villa Lía', 6735),
(6742010, 'Balneario San Cayetano', 6742),
(6742020, 'Ochandío', 6742),
(6742030, 'San Cayetano', 6742),
(6749010, 'San Fernando', 6749),
(6756010, 'San Isidro', 6756),
(6760010, 'San Miguel', 6760),
(6763010, 'Conesa', 6763),
(6763020, 'Erezcano', 6763),
(6763030, 'General Rojo', 6763),
(6763040, 'La Emilia', 6763),
(6763050, 'San Nicolás de los Arroyos', 6763),
(6763060, 'Villa Esperanza', 6763),
(6770010, 'Gobernador Castro', 6770),
(6770020, 'Obligado', 6770),
(6770030, 'Pueblo Doyle', 6770),
(6770040, 'Río Tala', 6770),
(6770050, 'San Pedro', 6770),
(6770060, 'Santa Lucía', 6770),
(6778020, 'San Vicente', 6778),
(6784010, 'General Rivas', 6784),
(6784020, 'Suipacha', 6784),
(6791010, 'De la Canal', 6791),
(6791030, 'Gardey', 6791),
(6791040, 'María Ignacia', 6791),
(6791050, 'Tandil', 6791),
(6798010, 'Crotto', 6798),
(6798020, 'Tapalqué', 6798),
(6798030, 'Velloso', 6798),
(6805010, 'Tigre', 6805),
(6812010, 'General Conesa', 6812),
(6819010, 'Chasicó', 6819),
(6819040, 'Tornquist', 6819),
(6819050, 'Tres Picos', 6819),
(6819060, 'La Gruta', 6819),
(6819070, 'Villa Ventana', 6819),
(6826010, 'Berutti', 6826),
(6826020, 'Girodias', 6826),
(6826030, 'La Carreta', 6826),
(6826040, '30 de Agosto', 6826),
(6826050, 'Trenque Lauquen', 6826),
(6826060, 'Trongé', 6826),
(6833010, 'Balneario Orense', 6833),
(6833020, 'Claromecó', 6833),
(6833030, 'Copetonas', 6833),
(6833040, 'Lin Calel', 6833),
(6833050, 'Micaela Cascallares', 6833),
(6833060, 'Orense', 6833),
(6833070, 'Reta', 6833),
(6833080, 'San Francisco de Bellocq', 6833),
(6833090, 'San Mayol', 6833),
(6833100, 'Tres Arroyos', 6833),
(6833110, 'Villa Rodríguez', 6833),
(6840010, 'Tres de Febrero', 6840),
(6847010, 'Ingeniero Thompson', 6847),
(6847020, 'Tres Lomas', 6847),
(6854010, 'Agustín Mosconi', 6854),
(6854020, 'Del Valle', 6854),
(6854030, 'Ernestina', 6854),
(6854040, 'Gobernador Ugarte', 6854),
(6854050, 'Lucas Monteverde', 6854),
(6854060, 'Norberto de la Riestra', 6854),
(6854070, 'Pedernales', 6854),
(6854080, 'San Enrique', 6854),
(6854090, 'Valdés', 6854),
(6854100, '25 de Mayo', 6854),
(6861010, 'Vicente López', 6861),
(6868010, 'Mar Azul', 6868),
(6868020, 'Villa Gesell', 6868),
(6875010, 'Argerich', 6875),
(6875030, 'Hilario Ascasubi', 6875),
(6875040, 'Juan Cousté', 6875),
(6875050, 'Mayor Buratovich', 6875),
(6875060, 'Médanos', 6875),
(6875070, 'Pedro Luro', 6875),
(6875080, 'Teniente Origone', 6875),
(6882030, 'Escalada', 6882),
(6882040, 'Lima', 6882),
(6882050, 'Zárate', 6882),
(10007010, 'Chuchucaruana', 10007),
(10007020, 'Colpes', 10007),
(10007030, 'El Bolsón', 10007),
(10007040, 'El Rodeo', 10007),
(10007050, 'Huaycama', 10007),
(10007060, 'La Puerta', 10007),
(10007070, 'Las Chacritas', 10007),
(10007080, 'Las Juntas', 10007),
(10007090, 'Los Castillos', 10007),
(10007100, 'Los Talas', 10007),
(10007110, 'Los Varela', 10007),
(10007120, 'Singuil', 10007),
(10014010, 'Ancasti', 10014),
(10014020, 'Anquincila', 10014),
(10014030, 'La Candelaria', 10014),
(10014040, 'La Majada', 10014),
(10021010, 'Amanao', 10021),
(10021020, 'Andalgalá', 10021),
(10021030, 'Chaquiago', 10021),
(10021040, 'Choya', 10021),
(10021050, 'El Alamito', 10021),
(10021060, 'El Lindero', 10021),
(10021070, 'El Potrero', 10021),
(10028010, 'Antofagasta de la Sierra', 10028),
(10028030, 'El Peñón', 10028),
(10028040, 'Los Nacimientos', 10028),
(10035010, 'Barranca Larga', 10035),
(10035020, 'Belén', 10035),
(10035030, 'Cóndor Huasi', 10035),
(10035040, 'Corral Quemado', 10035),
(10035050, 'El Durazno', 10035),
(10035060, 'Farallón Negro', 10035),
(10035070, 'Hualfín', 10035),
(10035080, 'Jacipunco', 10035),
(10035090, 'La Puntilla', 10035),
(10035100, 'Las Juntas', 10035),
(10035110, 'Londres', 10035),
(10035120, 'Los Nacimientos', 10035),
(10035130, 'Puerta de Corral Quemado', 10035),
(10035140, 'Puerta de San José', 10035),
(10035150, 'Villa Vil', 10035),
(10042030, 'Capayán', 10042),
(10042040, 'Chumbicha', 10042),
(10042050, 'Colonia del Valle', 10042),
(10042060, 'Colonia Nueva Coneta', 10042),
(10042070, 'Concepción', 10042),
(10042080, 'Coneta', 10042),
(10042090, 'El Bañado', 10042),
(10042100, 'Huillapima', 10042),
(10042110, 'Los Angeles', 10042),
(10042120, 'Miraflores', 10042),
(10042130, 'San Martín', 10042),
(10042140, 'San Pablo', 10042),
(10042150, 'San Pedro', 10042),
(10049030, 'San Fernando del Valle de Catamarca', 10049),
(10056010, 'El Alto', 10056),
(10056020, 'Guayamba', 10056),
(10056030, 'Infanzón', 10056),
(10056040, 'Los Corrales', 10056),
(10056050, 'Tapso', 10056),
(10056060, 'Vilismán', 10056),
(10063020, 'Pomancillo Este', 10063),
(10063030, 'Pomancillo Oeste', 10063),
(10063040, 'San José', 10063),
(10063050, 'Villa Las Pirquitas', 10063),
(10070010, 'Casa de Piedra', 10070),
(10070020, 'El Aybal', 10070),
(10070030, 'El Bañado', 10070),
(10070040, 'El Divisadero', 10070),
(10070050, 'El Quimilo', 10070),
(10070060, 'Esquiú', 10070),
(10070070, 'Icaño', 10070),
(10070080, 'La Dorada', 10070),
(10070090, 'La Guardia', 10070),
(10070100, 'Las Esquinas', 10070),
(10070110, 'Las Palmitas', 10070),
(10070120, 'Quirós', 10070),
(10070130, 'Ramblones', 10070),
(10070140, 'Recreo', 10070),
(10070150, 'San Antonio', 10070),
(10077010, 'Amadores', 10077),
(10077040, 'La Higuera', 10077),
(10077050, 'La Merced', 10077),
(10077060, 'La Viña', 10077),
(10077070, 'Las Lajas', 10077),
(10077080, 'Monte Potrero', 10077),
(10077090, 'Palo Labrado', 10077),
(10077100, 'San Antonio', 10077),
(10077110, 'Villa de Balcozna', 10077),
(10084020, 'Colana', 10084),
(10084030, 'Colpes', 10084),
(10084040, 'El Pajonal', 10084),
(10084060, 'Mutquin', 10084),
(10084070, 'Pomán', 10084),
(10084080, 'Rincón', 10084),
(10084090, 'San Miguel', 10084),
(10084100, 'Saujil', 10084),
(10084110, 'Siján', 10084),
(10091010, 'Andalhualá', 10091),
(10091030, 'Chañar Punco', 10091),
(10091040, 'El Cajón', 10091),
(10091050, 'El Desmonte', 10091),
(10091060, 'El Puesto', 10091),
(10091070, 'Famatanca', 10091),
(10091080, 'Fuerte Quemado', 10091),
(10091090, 'La Hoyada', 10091),
(10091110, 'Las Mojarras', 10091),
(10091130, 'Punta de Balasto', 10091),
(10091140, 'San José', 10091),
(10091150, 'Santa María', 10091),
(10091160, 'Yapes', 10091),
(10098010, 'Alijilán', 10098),
(10098020, 'Bañado de Ovanta', 10098),
(10098030, 'Las Cañas', 10098),
(10098040, 'Lavalle', 10098),
(10098050, 'Los Altos', 10098),
(10098060, 'Manantiales', 10098),
(10098070, 'San Pedro', 10098),
(10105010, 'Anillaco', 10105),
(10105050, 'Copacabana', 10105),
(10105090, 'El Puesto', 10105),
(10105100, 'El Salado', 10105),
(10105110, 'Fiambalá', 10105),
(10105130, 'Medanitos', 10105),
(10105140, 'Palo Blanco', 10105),
(10105160, 'Saujil', 10105),
(10105180, 'Tinogasta', 10105),
(10112010, 'El Portezuelo', 10112),
(10112020, 'Huaycama', 10112),
(10112030, 'Las Tejas', 10112),
(10112040, 'San Isidro', 10112),
(10112050, 'Santa Cruz', 10112),
(14007010, 'Amboy', 14007),
(14007020, 'Arroyo San Antonio', 14007),
(14007030, 'Cañada del Sauce', 14007),
(14007050, 'El Corcovado - El Torreón', 14007),
(14007055, 'El Durazno', 14007),
(14007060, 'Embalse', 14007),
(14007070, 'La Cruz', 14007),
(14007080, 'La Cumbrecita', 14007),
(14007090, 'Las Bajadas', 14007),
(14007100, 'Las Caleras', 14007),
(14007110, 'Los Cóndores', 14007),
(14007120, 'Los Molinos', 14007),
(14007130, 'Los Reartes', 14007),
(14007140, 'Lutti', 14007),
(14007160, 'Parque Calmayo', 14007),
(14007170, 'Río de los Sauces', 14007),
(14007180, 'San Agustín', 14007),
(14007190, 'San Ignacio (Loteo San Javier)', 14007),
(14007210, 'Santa Rosa de Calamuchita', 14007),
(14007220, 'Segunda Usina', 14007),
(14007230, 'Solar de los Molinos', 14007),
(14007240, 'Villa Alpina', 14007),
(14007250, 'Villa Amancay', 14007),
(14007260, 'Villa Berna', 14007),
(14007270, 'Villa Ciudad Parque Los Reartes', 14007),
(14007290, 'Villa del Dique', 14007),
(14007300, 'Villa El Tala', 14007),
(14007310, 'Villa General Belgrano', 14007),
(14007320, 'Villa La Rivera', 14007),
(14007330, 'Villa Quillinzo', 14007),
(14007340, 'Villa Rumipal', 14007),
(14007360, 'Villa Yacanto', 14007),
(14014010, 'Córdoba', 14014),
(14021010, 'Agua de Oro', 14021),
(14021020, 'Ascochinga', 14021),
(14021050, 'Colonia Caroya', 14021),
(14021060, 'Colonia Tirolesa', 14021),
(14021070, 'Colonia Vicente Agüero', 14021),
(14021075, 'Villa Corazón de María', 14021),
(14021110, 'El Manzano', 14021),
(14021130, 'General Paz', 14021),
(14021140, 'Jesús María', 14021),
(14021150, 'La Calera', 14021),
(14021160, 'La Granja', 14021),
(14021170, 'La Puerta', 14021),
(14021190, 'Malvinas Argentinas', 14021),
(14021200, 'Mendiolaza', 14021),
(14021210, 'Mi Granja', 14021),
(14021230, 'Río Ceballos', 14021),
(14021240, 'Saldán', 14021),
(14021250, 'Salsipuedes', 14021),
(14021270, 'Tinoco', 14021),
(14021280, 'Unquillo', 14021),
(14021290, 'Villa Allende', 14021),
(14021300, 'Villa Cerro Azul', 14021),
(14021310, 'Parque Norte - Ciudad de los Niños - Guiñazú Norte', 14021),
(14021320, 'Villa Los Llanos - Juárez Celman', 14021),
(14028010, 'Alto de los Quebrachos', 14028),
(14028020, 'Bañado de Soto', 14028),
(14028040, 'Cruz de Caña', 14028),
(14028050, 'Cruz del Eje', 14028),
(14028060, 'El Brete', 14028),
(14028080, 'Guanaco Muerto', 14028),
(14028100, 'La Batea', 14028),
(14028110, 'La Higuera', 14028),
(14028120, 'Las Cañadas', 14028),
(14028130, 'Las Playas', 14028),
(14028140, 'Los Chañaritos', 14028),
(14028150, 'Media Naranja', 14028),
(14028160, 'Paso Viejo', 14028),
(14028170, 'San Marcos Sierra', 14028),
(14028180, 'Serrezuela', 14028),
(14028190, 'Tuclame', 14028),
(14028200, 'Villa de Soto', 14028),
(14035010, 'Del Campillo', 14035),
(14035020, 'Estación Lecueder', 14035),
(14035030, 'Hipólito Bouchard', 14035),
(14035040, 'Huinca Renancó', 14035),
(14035050, 'Italó', 14035),
(14035060, 'Mattaldi', 14035),
(14035070, 'Nicolás Bruzzone', 14035),
(14035080, 'Onagoity', 14035),
(14035090, 'Pincén', 14035),
(14035100, 'Ranqueles', 14035),
(14035110, 'Santa Magdalena', 14035),
(14035120, 'Villa Huidobro', 14035),
(14035130, 'Villa Sarmiento', 14035),
(14035140, 'Villa Valeria', 14035),
(14042010, 'Arroyo Algodón', 14042),
(14042020, 'Arroyo Cabral', 14042),
(14042030, 'Ausonia', 14042),
(14042040, 'Chazón', 14042),
(14042050, 'Etruria', 14042),
(14042060, 'La Laguna', 14042),
(14042070, 'La Palestina', 14042),
(14042080, 'La Playosa', 14042),
(14042090, 'Las Mojarras', 14042),
(14042100, 'Luca', 14042),
(14042110, 'Pasco', 14042),
(14042120, 'Sanabria', 14042),
(14042130, 'Silvio Pellico', 14042),
(14042140, 'Ticino', 14042),
(14042150, 'Tío Pujio', 14042),
(14042170, 'Villa María', 14042),
(14042180, 'Villa Nueva', 14042),
(14042190, 'Villa Oeste', 14042),
(14049010, 'Avellaneda', 14049),
(14049020, 'Cañada de Río Pinto', 14049),
(14049030, 'Chuña', 14049),
(14049040, 'Copacabana', 14049),
(14049050, 'Deán Funes', 14049),
(14049080, 'Los Pozos', 14049),
(14049090, 'Olivares de San Nicolás', 14049),
(14049100, 'Quilino', 14049),
(14049110, 'San Pedro de Toyos', 14049),
(14049120, 'Villa Gutiérrez', 14049),
(14056010, 'Alejandro Roca', 14056),
(14056020, 'Assunta', 14056),
(14056030, 'Bengolea', 14056),
(14056040, 'Carnerillo', 14056),
(14056050, 'Charras', 14056),
(14056060, 'El Rastreador', 14056),
(14056070, 'General Cabrera', 14056),
(14056080, 'General Deheza', 14056),
(14056090, 'Huanchillas', 14056),
(14056100, 'La Carlota', 14056),
(14056110, 'Los Cisnes', 14056),
(14056120, 'Olaeta', 14056),
(14056130, 'Pacheco de Melo', 14056),
(14056140, 'Paso del Durazno', 14056),
(14056150, 'Santa Eufemia', 14056),
(14056160, 'Ucacha', 14056),
(14056170, 'Villa Reducción', 14056),
(14063010, 'Alejo Ledesma', 14063),
(14063020, 'Arias', 14063),
(14063030, 'Camilo Aldao', 14063),
(14063040, 'Capitán General Bernardo O\'Higgins', 14063),
(14063050, 'Cavanagh', 14063),
(14063060, 'Colonia Barge', 14063),
(14063070, 'Colonia Italiana', 14063),
(14063080, 'Colonia Veinticinco', 14063),
(14063090, 'Corral de Bustos', 14063),
(14063100, 'Cruz Alta', 14063),
(14063110, 'General Baldissera', 14063),
(14063120, 'General Roca', 14063),
(14063130, 'Guatimozín', 14063),
(14063140, 'Inriville', 14063),
(14063150, 'Isla Verde', 14063),
(14063160, 'Leones', 14063),
(14063170, 'Los Surgentes', 14063),
(14063180, 'Marcos Juárez', 14063),
(14063190, 'Monte Buey', 14063),
(14063210, 'Saira', 14063),
(14063220, 'Saladillo', 14063),
(14063230, 'Villa Elisa', 14063),
(14070010, 'Ciénaga del Coro', 14070),
(14070020, 'El Chacho', 14070),
(14070030, 'Estancia de Guadalupe', 14070),
(14070040, 'Guasapampa', 14070),
(14070050, 'La Playa', 14070),
(14070060, 'San Carlos Minas', 14070),
(14070070, 'Talaini', 14070),
(14070080, 'Tosno', 14070),
(14077010, 'Chancani', 14077),
(14077020, 'Las Palmas', 14077),
(14077030, 'Los Talares', 14077),
(14077040, 'Salsacate', 14077),
(14077050, 'San Gerónimo', 14077),
(14077060, 'Tala Cañada', 14077),
(14077080, 'Villa de Pocho', 14077),
(14084010, 'General Levalle', 14084),
(14084020, 'La Cesira', 14084),
(14084030, 'Laboulaye', 14084),
(14084040, 'Leguizamón', 14084),
(14084050, 'Melo', 14084),
(14084060, 'Río Bamba', 14084),
(14084070, 'Rosales', 14084),
(14084080, 'San Joaquín', 14084),
(14084090, 'Serrano', 14084),
(14084100, 'Villa Rossi', 14084),
(14091020, 'Bialet Massé', 14091),
(14091030, 'Cabalango', 14091),
(14091040, 'Capilla del Monte', 14091),
(14091050, 'Casa Grande', 14091),
(14091060, 'Charbonier', 14091),
(14091070, 'Cosquín', 14091),
(14091080, 'Cuesta Blanca', 14091),
(14091090, 'Estancia Vieja', 14091),
(14091100, 'Huerta Grande', 14091),
(14091110, 'La Cumbre', 14091),
(14091120, 'La Falda', 14091),
(14091130, 'Las Jarillas', 14091),
(14091140, 'Los Cocos', 14091),
(14091150, 'Mallín', 14091),
(14091160, 'Mayu Sumaj', 14091),
(14091180, 'San Antonio de Arredondo', 14091),
(14091190, 'San Esteban', 14091),
(14091200, 'San Roque', 14091),
(14091210, 'Santa María de Punilla', 14091),
(14091220, 'Tala Huasi', 14091),
(14091230, 'Tanti', 14091),
(14091240, 'Valle Hermoso', 14091),
(14091250, 'Villa Carlos Paz', 14091),
(14091260, 'Villa Flor Serrana', 14091),
(14091270, 'Villa Giardino', 14091),
(14091280, 'Villa Lago Azul', 14091),
(14091290, 'Villa Parque Siquimán', 14091),
(14091300, 'Villa Río Icho Cruz', 14091),
(14091320, 'Villa Santa Cruz del Lago', 14091),
(14098010, 'Achiras', 14098),
(14098020, 'Adelia María', 14098),
(14098030, 'Alcira Gigena', 14098),
(14098040, 'Alpa Corral', 14098),
(14098050, 'Berrotarán', 14098),
(14098060, 'Bulnes', 14098),
(14098070, 'Chaján', 14098),
(14098080, 'Chucul', 14098),
(14098090, 'Coronel Baigorria', 14098),
(14098100, 'Coronel Moldes', 14098),
(14098110, 'Elena', 14098),
(14098120, 'La Carolina', 14098),
(14098130, 'La Cautiva', 14098),
(14098140, 'La Gilda', 14098),
(14098150, 'Las Acequias', 14098),
(14098160, 'Las Albahacas', 14098),
(14098170, 'Las Higueras', 14098),
(14098180, 'Las Peñas', 14098),
(14098190, 'Las Vertientes', 14098),
(14098200, 'Malena', 14098),
(14098210, 'Monte de los Gauchos', 14098),
(14098230, 'Río Cuarto', 14098),
(14098240, 'Sampacho', 14098),
(14098250, 'San Basilio', 14098),
(14098260, 'Santa Catalina Holmberg', 14098),
(14098270, 'Suco', 14098),
(14098280, 'Tosquitas', 14098),
(14098290, 'Vicuña Mackenna', 14098),
(14098300, 'Villa El Chacay', 14098),
(14098320, 'Washington', 14098),
(14105010, 'Atahona', 14105),
(14105020, 'Cañada de Machado', 14105),
(14105030, 'Capilla de los Remedios', 14105),
(14105040, 'Chalacea', 14105),
(14105050, 'Colonia Las Cuatro Esquinas', 14105),
(14105060, 'Diego de Rojas', 14105),
(14105070, 'El Alcalde', 14105),
(14105080, 'El Crispín', 14105),
(14105090, 'Esquina', 14105),
(14105100, 'Kilómetro 658', 14105),
(14105110, 'La Para', 14105),
(14105120, 'La Posta', 14105),
(14105130, 'La Puerta', 14105),
(14105140, 'La Quinta', 14105),
(14105150, 'Las Gramillas', 14105),
(14105160, 'Las Saladas', 14105),
(14105170, 'Maquinista Gallini', 14105),
(14105180, 'Monte del Rosario', 14105),
(14105190, 'Montecristo', 14105),
(14105200, 'Obispo Trejo', 14105),
(14105210, 'Piquillín', 14105),
(14105220, 'Plaza de Mercedes', 14105),
(14105230, 'Pueblo Comechingones', 14105),
(14105240, 'Río Primero', 14105),
(14105250, 'Sagrada Familia', 14105),
(14105260, 'Santa Rosa de Río Primero', 14105),
(14105270, 'Villa Fontana', 14105),
(14112010, 'Cerro Colorado', 14112),
(14112020, 'Chañar Viejo', 14112),
(14112030, 'Eufrasio Loza', 14112),
(14112040, 'Gutemberg', 14112),
(14112050, 'La Rinconada', 14112),
(14112060, 'Los Hoyos', 14112),
(14112070, 'Puesto de Castro', 14112),
(14112080, 'Rayo Cortado', 14112),
(14112090, 'San Pedro de Gütemberg', 14112),
(14112100, 'Santa Elena', 14112),
(14112110, 'Sebastián Elcano', 14112),
(14112120, 'Villa Candelaria', 14112),
(14112130, 'Villa de María', 14112),
(14119010, 'Calchín', 14119),
(14119020, 'Calchín Oeste', 14119),
(14119030, 'Capilla del Carmen', 14119),
(14119040, 'Carrilobo', 14119),
(14119050, 'Colazo', 14119),
(14119060, 'Colonia Videla', 14119),
(14119070, 'Costasacate', 14119),
(14119080, 'Impira', 14119),
(14119090, 'Laguna Larga', 14119),
(14119100, 'Las Junturas', 14119),
(14119110, 'Los Chañaritos', 14119),
(14119120, 'Luque', 14119),
(14119130, 'Manfredi', 14119),
(14119140, 'Matorrales', 14119),
(14119150, 'Oncativo', 14119),
(14119160, 'Pilar', 14119),
(14119170, 'Pozo del Molle', 14119),
(14119180, 'Rincón', 14119),
(14119190, 'Río Segundo', 14119),
(14119200, 'Santiago Temple', 14119),
(14119210, 'Villa del Rosario', 14119),
(14126010, 'Ambul', 14126),
(14126020, 'Arroyo Los Patos', 14126),
(14126050, 'Las Calles', 14126),
(14126070, 'Las Rabonas', 14126),
(14126090, 'Mina Clavero', 14126),
(14126100, 'Mussi', 14126),
(14126110, 'Nono', 14126),
(14126120, 'Panaholma', 14126),
(14126140, 'San Lorenzo', 14126),
(14126150, 'San Martín', 14126),
(14126160, 'San Pedro', 14126),
(14126170, 'San Vicente', 14126),
(14126180, 'Sauce Arriba', 14126),
(14126200, 'Villa Cura Brochero', 14126),
(14126210, 'Villa Sarmiento', 14126),
(14133010, 'Conlara', 14133),
(14133060, 'La Paz', 14133),
(14133070, 'La Población', 14133),
(14133090, 'La Travesía', 14133),
(14133100, 'Las Tapias', 14133),
(14133110, 'Los Cerrillos', 14133),
(14133120, 'Los Hornillos', 14133),
(14133150, 'Luyaba', 14133),
(14133170, 'San Javier y Yacanto', 14133),
(14133180, 'San José', 14133),
(14133190, 'Villa de las Rosas', 14133),
(14133200, 'Villa Dolores', 14133),
(14133210, 'Villa La Viña', 14133),
(14140010, 'Alicia', 14140),
(14140020, 'Altos de Chipión', 14140),
(14140030, 'Arroyito', 14140),
(14140040, 'Balnearia', 14140),
(14140050, 'Brinkmann', 14140),
(14140060, 'Colonia Anita', 14140),
(14140070, 'Colonia 10 de Julio', 14140),
(14140080, 'Colonia Las Pichanas', 14140),
(14140090, 'Colonia Marina', 14140),
(14140100, 'Colonia Prosperidad', 14140),
(14140110, 'Colonia San Bartolomé', 14140),
(14140120, 'Colonia San Pedro', 14140),
(14140130, 'Colonia Santa María', 14140),
(14140140, 'Colonia Valtelina', 14140),
(14140150, 'Colonia Vignaud', 14140),
(14140160, 'Devoto', 14140),
(14140170, 'El Arañado', 14140),
(14140180, 'El Fortín', 14140),
(14140190, 'El Fuertecito', 14140),
(14140200, 'El Tío', 14140),
(14140210, 'Estación Luxardo', 14140),
(14140215, 'Colonia Iturraspe', 14140),
(14140220, 'Freyre', 14140),
(14140230, 'La Francia', 14140),
(14140240, 'La Paquita', 14140),
(14140250, 'La Tordilla', 14140),
(14140260, 'Las Varas', 14140),
(14140270, 'Las Varillas', 14140),
(14140280, 'Marull', 14140),
(14140290, 'Miramar', 14140),
(14140300, 'Morteros', 14140),
(14140310, 'Plaza Luxardo', 14140),
(14140320, 'Plaza San Francisco', 14140),
(14140330, 'Porteña', 14140),
(14140340, 'Quebracho Herrado', 14140),
(14140350, 'Sacanta', 14140),
(14140360, 'San Francisco', 14140),
(14140370, 'Saturnino María Laspiur', 14140),
(14140380, 'Seeber', 14140),
(14140390, 'Toro Pujio', 14140),
(14140400, 'Tránsito', 14140),
(14140420, 'Villa Concepción del Tío', 14140),
(14140430, 'Villa del Tránsito', 14140),
(14140440, 'Villa San Esteban', 14140),
(14147010, 'Alta Gracia', 14147),
(14147020, 'Anisacate', 14147),
(14147030, 'Barrio Gilbert (1º de Mayo) - Tejas Tres', 14147),
(14147050, 'Bouwer', 14147),
(14147060, 'Caseros Centro', 14147),
(14147080, 'Despeñaderos', 14147),
(14147090, 'Dique Chico', 14147),
(14147100, 'Falda del Cañete', 14147),
(14147110, 'Falda del Carmen', 14147),
(14147115, 'José de la Quintana', 14147),
(14147120, 'La Boca del Río', 14147),
(14147150, 'La Paisanita', 14147),
(14147170, 'La Rancherita y Las Cascadas', 14147),
(14147180, 'La Serranita', 14147),
(14147190, 'Los Cedros', 14147),
(14147200, 'Lozada', 14147),
(14147210, 'Malagueño', 14147),
(14147220, 'Monte Ralo', 14147),
(14147230, 'Potrero de Garay', 14147),
(14147240, 'Rafael García', 14147),
(14147250, 'San Clemente', 14147),
(14147270, 'Socavones', 14147),
(14147280, 'Toledo', 14147),
(14147300, 'Valle de Anisacate', 14147),
(14147310, 'Villa Ciudad de América', 14147),
(14147320, 'Villa del Prado', 14147),
(14147330, 'Villa La Bolsa', 14147),
(14147340, 'Villa Los Aromos', 14147),
(14147350, 'Villa Parque Santa Ana', 14147),
(14147360, 'Villa San Isidro', 14147),
(14154010, 'Caminiaga', 14154),
(14154030, 'Chuña Huasi', 14154),
(14154040, 'Pozo Nuevo', 14154),
(14154050, 'San Francisco del Chañar', 14154),
(14161010, 'Almafuerte', 14161),
(14161020, 'Colonia Almada', 14161),
(14161030, 'Corralito', 14161),
(14161040, 'Dalmacio Vélez', 14161),
(14161050, 'General Fotheringham', 14161),
(14161060, 'Hernando', 14161),
(14161070, 'James Craik', 14161),
(14161080, 'Las Isletillas', 14161),
(14161090, 'Las Perdices', 14161),
(14161100, 'Los Zorros', 14161),
(14161110, 'Oliva', 14161),
(14161120, 'Pampayasta Norte', 14161),
(14161130, 'Pampayasta Sud', 14161),
(14161140, 'Punta del Agua', 14161),
(14161150, 'Río Tercero', 14161),
(14161160, 'Tancacha', 14161),
(14161170, 'Villa Ascasubi', 14161),
(14168010, 'Candelaria Sur', 14168),
(14168020, 'Cañada de Luque', 14168),
(14168030, 'Capilla de Sitón', 14168),
(14168040, 'La Pampa', 14168),
(14168060, 'Las Peñas', 14168),
(14168070, 'Los Mistoles', 14168),
(14168080, 'Santa Catalina', 14168),
(14168090, 'Sarmiento', 14168),
(14168100, 'Simbolar', 14168),
(14168110, 'Sinsacate', 14168),
(14168120, 'Villa del Totoral', 14168),
(14175020, 'Churqui Cañada', 14175),
(14175030, 'El Rodeo', 14175),
(14175040, 'El Tuscal', 14175),
(14175050, 'Las Arrias', 14175),
(14175060, 'Lucio V. Mansilla', 14175),
(14175070, 'Rosario del Saladillo', 14175),
(14175080, 'San José de la Dormida', 14175),
(14175090, 'San José de las Salinas', 14175),
(14175100, 'San Pedro Norte', 14175),
(14175110, 'Villa Tulumba', 14175),
(14182010, 'Aldea Santa María', 14182),
(14182020, 'Alto Alegre', 14182),
(14182030, 'Ana Zumarán', 14182),
(14182040, 'Ballesteros', 14182),
(14182050, 'Ballesteros Sud', 14182),
(14182060, 'Bell Ville', 14182),
(14182070, 'Benjamín Gould', 14182),
(14182080, 'Canals', 14182),
(14182090, 'Chilibroste', 14182),
(14182100, 'Cintra', 14182),
(14182110, 'Colonia Bismarck', 14182),
(14182120, 'Colonia Bremen', 14182),
(14182130, 'Idiazabal', 14182),
(14182140, 'Justiniano Posse', 14182),
(14182150, 'Laborde', 14182),
(14182160, 'Monte Leña', 14182),
(14182170, 'Monte Maíz', 14182),
(14182180, 'Morrison', 14182),
(14182190, 'Noetinger', 14182),
(14182200, 'Ordoñez', 14182),
(14182210, 'Pascanas', 14182),
(14182220, 'Pueblo Italiano', 14182),
(14182230, 'Ramón J. Cárcano', 14182),
(14182240, 'San Antonio de Litín', 14182),
(14182250, 'San Marcos', 14182),
(14182260, 'San Severo', 14182),
(14182270, 'Viamonte', 14182),
(14182280, 'Villa Los Patos', 14182),
(14182290, 'Wenceslao Escalante', 14182),
(18007010, 'Bella Vista', 18007),
(18014010, 'Berón de Astrada', 18014),
(18014020, 'Yahapé', 18014),
(18021020, 'Corrientes', 18021),
(18021040, 'Riachuelo', 18021),
(18021050, 'San Cayetano', 18021),
(18028010, 'Concepción', 18028),
(18028020, 'Santa Rosa', 18028),
(18028030, 'Tabay', 18028),
(18028040, 'Tatacua', 18028),
(18035010, 'Cazadores Correntinos', 18035),
(18035020, 'Curuzú Cuatiá', 18035),
(18035030, 'Perugorría', 18035),
(18042010, 'El Sombrero', 18042),
(18042020, 'Empedrado', 18042),
(18049010, 'Esquina', 18049),
(18049020, 'Pueblo Libertador', 18049),
(18056010, 'Alvear', 18056),
(18056020, 'Estación Torrent', 18056),
(18063010, 'Itá Ibaté', 18063),
(18063020, 'Lomas de Vallejos', 18063),
(18063030, 'Nuestra Señora del Rosario de Caá Catí', 18063),
(18063040, 'Palmar Grande', 18063),
(18070010, 'Carolina', 18070),
(18070020, 'Goya', 18070),
(18077010, 'Itatí', 18077),
(18077020, 'Ramada Paso', 18077),
(18084010, 'Colonia Liebig\'s', 18084),
(18084020, 'Ituzaingó', 18084),
(18084030, 'San Antonio', 18084),
(18084040, 'San Carlos', 18084),
(18084050, 'Villa Olivari', 18084),
(18091010, 'Cruz de los Milagros', 18091),
(18091020, 'Gobernador Juan E. Martínez', 18091),
(18091030, 'Lavalle', 18091),
(18091040, 'Santa Lucía', 18091),
(18091050, 'Villa Córdoba', 18091),
(18091060, 'Yatayti Calle', 18091),
(18098010, 'Mburucuyá', 18098),
(18105010, 'Felipe Yofré', 18105),
(18105020, 'Mariano I. Loza', 18105),
(18105030, 'Mercedes', 18105),
(18112010, 'Colonia Libertad', 18112),
(18112020, 'Estación Libertad', 18112),
(18112030, 'Juan Pujol', 18112),
(18112040, 'Mocoretá', 18112),
(18112050, 'Monte Caseros', 18112),
(18112060, 'Parada Acuña', 18112),
(18112070, 'Parada Labougle', 18112),
(18119010, 'Bonpland', 18119),
(18119020, 'Parada Pucheta', 18119),
(18119030, 'Paso de los Libres', 18119),
(18119040, 'Tapebicuá', 18119),
(18126010, 'Saladas', 18126),
(18126020, 'San Lorenzo', 18126),
(18133010, 'Ingenio Primer Correntino', 18133),
(18133020, 'Paso de la Patria', 18133),
(18133030, 'San Cosme', 18133),
(18133040, 'Santa Ana', 18133),
(18140010, 'San Luis del Palmar', 18140),
(18147010, 'Colonia Carlos Pellegrini', 18147),
(18147020, 'Guaviraví', 18147),
(18147030, 'La Cruz', 18147),
(18147040, 'Yapeyú', 18147),
(18154010, 'Loreto', 18154),
(18154020, 'San Miguel', 18154),
(18161010, 'Chavarría', 18161),
(18161020, 'Colonia Pando', 18161),
(18161030, '9 de Julio', 18161),
(18161040, 'Pedro R. Fernández', 18161),
(18161050, 'San Roque', 18161),
(18168010, 'José Rafael Gómez', 18168),
(18168020, 'Garruchos', 18168),
(18168030, 'Gobernador Igr. Valentín Virasoro', 18168),
(18168040, 'Santo Tomé', 18168),
(18175010, 'Sauce', 18175),
(22007010, 'Concepción del Bermejo', 22007),
(22007020, 'Los Frentones', 22007),
(22007030, 'Pampa del Infierno', 22007),
(22007040, 'Río Muerto', 22007),
(22007050, 'Taco Pozo', 22007),
(22014010, 'General Vedia', 22014),
(22014020, 'Isla del Cerrito', 22014),
(22014030, 'La Leonesa', 22014),
(22014040, 'Las Palmas', 22014),
(22014050, 'Puerto Bermejo Nuevo', 22014),
(22014060, 'Puerto Bermejo Viejo', 22014),
(22014070, 'Puerto Eva Perón', 22014),
(22021010, 'Presidencia Roque Sáenz Peña', 22021),
(22028010, 'Charata', 22028),
(22036010, 'Gancedo', 22036),
(22036020, 'General Capdevila', 22036),
(22036030, 'General Pinedo', 22036),
(22036040, 'Mesón de Fierro', 22036),
(22036050, 'Pampa Landriel', 22036),
(22039010, 'Hermoso Campo', 22039),
(22039020, 'Itín', 22039),
(22043010, 'Chorotis', 22043),
(22043020, 'Santa Sylvina', 22043),
(22043030, 'Venados Grandes', 22043),
(22049010, 'Corzuela', 22049),
(22056010, 'La Escondida', 22056),
(22056020, 'La Verde', 22056),
(22056030, 'Lapachito', 22056),
(22056040, 'Makallé', 22056),
(22063010, 'El Espinillo', 22063),
(22063020, 'El Sauzal', 22063),
(22063030, 'El Sauzalito', 22063),
(22063040, 'Fortín Lavalle', 22063),
(22063050, 'Fuerte Esperanza', 22063),
(22063060, 'Juan José Castelli', 22063),
(22063070, 'Miraflores', 22063),
(22063080, 'Nueva Pompeya', 22063),
(22063100, 'Villa Río Bermejito', 22063),
(22063110, 'Wichi', 22063),
(22063120, 'Zaparinqui', 22063),
(22070010, 'Avia Terai', 22070),
(22070020, 'Campo Largo', 22070),
(22070030, 'Fortín Las Chuñas', 22070),
(22070040, 'Napenay', 22070),
(22077010, 'Colonia Popular', 22077),
(22077020, 'Estación General Obligado', 22077),
(22077030, 'Laguna Blanca', 22077),
(22077040, 'Puerto Tirol', 22077),
(22084010, 'Ciervo Petiso', 22084),
(22084020, 'General José de San Martín', 22084),
(22084030, 'La Eduvigis', 22084),
(22084040, 'Laguna Limpia', 22084),
(22084050, 'Pampa Almirón', 22084),
(22084060, 'Pampa del Indio', 22084),
(22084070, 'Presidencia Roca', 22084),
(22084080, 'Selvas del Río de Oro', 22084),
(22091010, 'Tres Isletas', 22091),
(22098010, 'Coronel Du Graty', 22098),
(22098020, 'Enrique Urien', 22098),
(22098030, 'Villa Angela', 22098),
(22105010, 'Las Breñas', 22105),
(22112010, 'La Clotilde', 22112),
(22112020, 'La Tigra', 22112),
(22112030, 'San Bernardo', 22112),
(22119010, 'Presidencia de la Plaza', 22119),
(22126010, 'Barrio de los Pescadores', 22126),
(22126020, 'Colonia Benítez', 22126),
(22126030, 'Margarita Belén', 22126),
(22133010, 'Quitilipi', 22133),
(22133020, 'Villa El Palmar', 22133),
(22140010, 'Barranqueras', 22140),
(22140020, 'Basail', 22140),
(22140030, 'Colonia Baranda', 22140),
(22140040, 'Fontana', 22140),
(22140050, 'Puerto Vilelas', 22140),
(22140060, 'Resistencia', 22140),
(22147010, 'Samuhú', 22147),
(22147020, 'Villa Berthet', 22147),
(22154010, 'Capitán Solari', 22154),
(22154020, 'Colonia Elisa', 22154),
(22154030, 'Colonias Unidas', 22154),
(22154040, 'Ingeniero Barbet', 22154),
(22154050, 'Las Garcitas', 22154),
(22161010, 'Charadai', 22161),
(22161020, 'Cote Lai', 22161),
(22161030, 'Haumonia', 22161),
(22161040, 'Horquilla', 22161),
(22161050, 'La Sabana', 22161),
(22168010, 'Colonia Aborigen', 22168),
(22168020, 'Machagai', 22168),
(22168030, 'Napalpí', 22168),
(26007010, 'Arroyo Verde', 26007),
(26007020, 'Puerto Madryn', 26007),
(26007030, 'Puerto Pirámides', 26007),
(26007040, 'Quintas El Mirador', 26007),
(26007050, 'Reserva Area Protegida El Doradillo', 26007),
(26014010, 'Buenos Aires Chico', 26014),
(26014020, 'Cholila', 26014),
(26014025, 'Costa del Chubut', 26014),
(26014030, 'Cushamen Centro', 26014),
(26014040, 'El Hoyo', 26014),
(26014050, 'El Maitén', 26014),
(26014060, 'Epuyén', 26014),
(26014065, 'Fofo Cahuel', 26014),
(26014070, 'Gualjaina', 26014),
(26014080, 'Lago Epuyén', 26014),
(26014090, 'Lago Puelo', 26014),
(26014100, 'Leleque', 26014),
(26021010, 'Astra', 26021),
(26021020, 'Bahía Bustamante', 26021),
(26021030, 'Comodoro Rivadavia', 26021),
(26021040, 'Diadema Argentina', 26021),
(26021050, 'Rada Tilly', 26021),
(26028010, 'Camarones', 26028),
(26028020, 'Garayalde', 26028),
(26035010, 'Aldea Escolar (Los Rápidos)', 26035),
(26035020, 'Corcovado', 26035),
(26035030, 'Esquel', 26035),
(26035040, 'Lago Rosario', 26035),
(26035050, 'Los Cipreses', 26035),
(26035060, 'Trevelín', 26035),
(26035070, 'Villa Futalaufquen', 26035),
(26042010, 'Dique Florentino Ameghino', 26042),
(26042020, 'Dolavon', 26042),
(26042030, 'Gaiman', 26042),
(26042040, '28 de Julio', 26042),
(26049010, 'Blancuntre', 26049),
(26049020, 'El Escorial', 26049),
(26049030, 'Gastre', 26049),
(26049040, 'Lagunita Salada', 26049),
(26049050, 'Yala Laubat', 26049),
(26056010, 'Aldea Epulef', 26056),
(26056020, 'Carrenleufú', 26056),
(26056030, 'Colan Conhué', 26056),
(26056040, 'Paso del Sapo', 26056),
(26056050, 'Tecka', 26056),
(26063010, 'El Mirasol', 26063),
(26063020, 'Las Plumas', 26063),
(26070010, 'Cerro Cóndor', 26070),
(26070020, 'Los Altares', 26070),
(26070030, 'Paso de Indios', 26070),
(26077010, 'Playa Magagna', 26077),
(26077020, 'Playa Unión', 26077),
(26077030, 'Rawson', 26077),
(26077040, 'Trelew', 26077),
(26084010, 'Aldea Apeleg', 26084),
(26084020, 'Aldea Beleiro', 26084),
(26084030, 'Alto Río Senguer', 26084),
(26084040, 'Doctor Ricardo Rojas', 26084),
(26084050, 'Facundo', 26084),
(26084060, 'Lago Blanco', 26084),
(26084070, 'Río Mayo', 26084),
(26091010, 'Buen Pasto', 26091),
(26091020, 'Sarmiento', 26091),
(26098010, 'Doctor Oscar Atilio Viglione (Frontera de Río Pico)', 26098),
(26098020, 'Gobernador Costa', 26098),
(26098030, 'José de San Martín', 26098),
(26098040, 'Río Pico', 26098),
(26105010, 'Gan Gan', 26105),
(26105020, 'Telsen', 26105),
(30008010, 'Arroyo Barú', 30008),
(30008020, 'Colón', 30008),
(30008030, 'Colonia Hugues', 30008),
(30008040, 'Hambis', 30008),
(30008050, 'Hocker', 30008),
(30008060, 'La Clarita', 30008),
(30008070, 'Pueblo Cazes', 30008),
(30008080, 'Pueblo Liebig\'s', 30008),
(30008090, 'San José', 30008),
(30008100, 'Ubajay', 30008),
(30008110, 'Villa Elisa', 30008),
(30015010, 'Calabacilla', 30015),
(30015020, 'Clodomiro Ledesma', 30015),
(30015030, 'Colonia Ayuí', 30015),
(30015040, 'Colonia General Roca', 30015),
(30015060, 'Concordia', 30015),
(30015080, 'Estación Yeruá', 30015),
(30015083, 'Estación Yuquerí', 30015),
(30015087, 'Estancia Grande', 30015),
(30015090, 'La Criolla', 30015),
(30015100, 'Los Charrúas', 30015),
(30015110, 'Nueva Escocia', 30015),
(30015120, 'Osvaldo Magnasco', 30015),
(30015130, 'Pedernal', 30015),
(30015140, 'Puerto Yeruá', 30015),
(30021010, 'Aldea Brasilera', 30021),
(30021015, 'Aldea Grapschental', 30021),
(30021020, 'Aldea Protestante', 30021),
(30021030, 'Aldea Salto', 30021),
(30021040, 'Aldea San Francisco', 30021),
(30021050, 'Aldea Spatzenkutter', 30021),
(30021060, 'Aldea Valle María', 30021),
(30021070, 'Colonia Ensayo', 30021),
(30021080, 'Diamante', 30021),
(30021090, 'Estación Camps', 30021),
(30021100, 'General Alvear', 30021),
(30021110, 'General Racedo (El Carmen)', 30021),
(30021120, 'General Ramírez', 30021),
(30021123, 'La Juanita', 30021),
(30021127, 'Las Jaulas', 30021),
(30021130, 'Paraje La Virgen', 30021),
(30021140, 'Puerto Las Cuevas', 30021),
(30021150, 'Villa Libertador San Martín', 30021),
(30028010, 'Chajarí', 30028),
(30028020, 'Colonia Alemana', 30028),
(30028040, 'Colonia La Argentina', 30028),
(30028070, 'Federación', 30028),
(30028080, 'Los Conquistadores', 30028),
(30028090, 'San Jaime de la Frontera', 30028),
(30028100, 'San Pedro', 30028),
(30028105, 'San Ramón', 30028),
(30028110, 'Santa Ana', 30028),
(30028120, 'Villa del Rosario', 30028),
(30035010, 'Conscripto Bernardi', 30035),
(30035020, 'Aldea San Isidro (El Cimarrón)', 30035),
(30035030, 'Federal', 30035),
(30035040, 'Nueva Vizcaya', 30035),
(30035050, 'Sauce de Luna', 30035),
(30042010, 'San José de Feliciano', 30042),
(30042020, 'San Víctor', 30042),
(30049010, 'Aldea Asunción', 30049),
(30049020, 'Estación Lazo', 30049),
(30049030, 'General Galarza', 30049),
(30049040, 'Gualeguay', 30049),
(30049050, 'Puerto Ruiz', 30049),
(30056010, 'Aldea San Antonio', 30056),
(30056020, 'Aldea San Juan', 30056),
(30056030, 'Enrique Carbó', 30056),
(30056035, 'Estación Escriña', 30056),
(30056040, 'Faustino M. Parera', 30056),
(30056050, 'General Almada', 30056),
(30056060, 'Gilbert', 30056),
(30056070, 'Gualeguaychú', 30056),
(30056080, 'Irazusta', 30056),
(30056090, 'Larroque', 30056),
(30056095, 'Pastor Britos', 30056),
(30056100, 'Pueblo General Belgrano', 30056),
(30056110, 'Urdinarrain', 30056),
(30063020, 'Ceibas', 30063),
(30063030, 'Ibicuy', 30063),
(30063040, 'Médanos', 30063),
(30063060, 'Villa Paranacito', 30063),
(30070005, 'Alcaraz', 30070),
(30070010, 'Bovril', 30070),
(30070020, 'Colonia Avigdor', 30070),
(30070030, 'El Solar', 30070),
(30070040, 'La Paz', 30070),
(30070050, 'Piedras Blancas', 30070),
(30070070, 'San Gustavo', 30070),
(30070080, 'Santa Elena', 30070),
(30070090, 'Sir Leonard', 30070),
(30077010, 'Aranguren', 30077),
(30077020, 'Betbeder', 30077),
(30077030, 'Don Cristóbal', 30077),
(30077040, 'Febré', 30077),
(30077050, 'Hernández', 30077),
(30077060, 'Lucas González', 30077),
(30077070, 'Nogoyá', 30077),
(30077080, 'XX de Setiembre', 30077),
(30084010, 'Aldea María Luisa', 30084),
(30084015, 'Aldea San Juan', 30084),
(30084020, 'Aldea San Rafael', 30084),
(30084030, 'Aldea Santa María', 30084),
(30084040, 'Aldea Santa Rosa', 30084),
(30084050, 'Cerrito', 30084),
(30084060, 'Colonia Avellaneda', 30084),
(30084065, 'Colonia Crespo', 30084),
(30084070, 'Crespo', 30084),
(30084080, 'El Palenque', 30084),
(30084090, 'El Pingo', 30084),
(30084095, 'El Ramblón', 30084),
(30084100, 'Hasenkamp', 30084),
(30084110, 'Hernandarias', 30084),
(30084120, 'La Picada', 30084),
(30084130, 'Las Tunas', 30084),
(30084140, 'María Grande', 30084),
(30084150, 'Oro Verde', 30084),
(30084160, 'Paraná', 30084),
(30084170, 'Pueblo Bellocq (Las Garzas)', 30084),
(30084180, 'Pueblo Brugo', 30084),
(30084190, 'Pueblo General San Martín', 30084),
(30084200, 'San Benito', 30084),
(30084210, 'Sauce Montrull', 30084),
(30084220, 'Sauce Pinto', 30084),
(30084230, 'Seguí', 30084),
(30084240, 'Sosa', 30084),
(30084250, 'Tabossi', 30084),
(30084260, 'Tezanos Pinto', 30084),
(30084270, 'Viale', 30084),
(30084280, 'Villa Fontana', 30084),
(30084290, 'Villa Gdor. Luis F. Etchevehere', 30084),
(30084300, 'Villa Urquiza', 30084),
(30088010, 'General Campos', 30088),
(30088020, 'San Salvador', 30088),
(30091010, 'Altamirano Sur', 30091),
(30091020, 'Durazno', 30091),
(30091030, 'Estación Arroyo Clé', 30091),
(30091040, 'Gobernador Echagüe', 30091),
(30091050, 'Gobernador Mansilla', 30091),
(30091060, 'Gobernador Solá', 30091),
(30091070, 'Guardamonte', 30091),
(30091080, 'Las Guachas', 30091),
(30091090, 'Maciá', 30091),
(30091100, 'Rosario del Tala', 30091),
(30098010, 'Basavilbaso', 30098),
(30098020, 'Caseros', 30098),
(30098030, 'Colonia Elía', 30098),
(30098040, 'Concepción del Uruguay', 30098),
(30098060, 'Herrera', 30098),
(30098070, 'Las Moscas', 30098),
(30098080, 'Líbaros', 30098),
(30098090, '1º de Mayo', 30098),
(30098100, 'Pronunciamiento', 30098),
(30098110, 'Rocamora', 30098),
(30098120, 'Santa Anita', 30098),
(30098130, 'Villa Mantero', 30098),
(30098140, 'Villa San Justo', 30098),
(30098150, 'Villa San Marcial (Est. Gobernador Urquiza)', 30098),
(30105010, 'Antelo', 30105),
(30105040, 'Molino Doll', 30105),
(30105060, 'Victoria', 30105),
(30113010, 'Estación Raíces', 30113),
(30113020, 'Ingeniero Miguel Sajaroff', 30113);
INSERT INTO `localidad` (`id_localidad`, `nombre`, `id_partido`) VALUES
(30113030, 'Jubileo', 30113),
(30113050, 'Paso de la Laguna', 30113),
(30113060, 'Villa Clara', 30113),
(30113070, 'Villa Domínguez', 30113),
(30113080, 'Villaguay', 30113),
(34007003, 'Fortín Soledad', 34007),
(34007005, 'Guadalcazar', 34007),
(34007007, 'La Rinconada', 34007),
(34007010, 'Laguna Yema', 34007),
(34007015, 'Lamadrid', 34007),
(34007020, 'Los Chiriguanos', 34007),
(34007030, 'Pozo de Maza', 34007),
(34007040, 'Pozo del Mortero', 34007),
(34007050, 'Vaca Perdida', 34007),
(34014010, 'Colonia Pastoril', 34014),
(34014020, 'Formosa', 34014),
(34014030, 'Gran Guardia', 34014),
(34014040, 'Mariano Boedo', 34014),
(34014050, 'Mojón de Fierro', 34014),
(34014060, 'San Hilario', 34014),
(34021010, 'Banco Payaguá', 34021),
(34021020, 'General Lucio V. Mansilla', 34021),
(34021030, 'Herradura', 34021),
(34021040, 'San Francisco de Laishi', 34021),
(34021050, 'Tatané', 34021),
(34021060, 'Villa Escolar', 34021),
(34028010, 'Ingeniero Guillermo N. Juárez', 34028),
(34035010, 'Bartolomé de las Casas', 34035),
(34035020, 'Colonia Sarmiento', 34035),
(34035030, 'Comandante Fontana', 34035),
(34035040, 'El Recreo', 34035),
(34035050, 'Estanislao del Campo', 34035),
(34035060, 'Fortín Cabo 1º Lugones', 34035),
(34035070, 'Fortín Sargento 1º Leyes', 34035),
(34035080, 'Ibarreta', 34035),
(34035090, 'Juan G. Bazán', 34035),
(34035100, 'Las Lomitas', 34035),
(34035110, 'Posta Cambio Zalazar', 34035),
(34035120, 'Pozo del Tigre', 34035),
(34035130, 'San Martín I', 34035),
(34035140, 'San Martín II', 34035),
(34035150, 'Subteniente Perín', 34035),
(34035160, 'Villa General Güemes', 34035),
(34035170, 'Villa General Manuel Belgrano', 34035),
(34042010, 'Buena Vista', 34042),
(34042020, 'El Espinillo', 34042),
(34042030, 'Laguna Gallo', 34042),
(34042040, 'Misión Tacaaglé', 34042),
(34042050, 'Portón Negro', 34042),
(34042060, 'Tres Lagunas', 34042),
(34049010, 'Clorinda', 34049),
(34049020, 'Laguna Blanca', 34049),
(34049030, 'Laguna Naick-Neck', 34049),
(34049040, 'Palma Sola', 34049),
(34049050, 'Puerto Pilcomayo', 34049),
(34049060, 'Riacho He-He', 34049),
(34049070, 'Riacho Negro', 34049),
(34049080, 'Siete Palmas', 34049),
(34056010, 'Colonia Campo Villafañe', 34056),
(34056020, 'El Colorado', 34056),
(34056030, 'Palo Santo', 34056),
(34056040, 'Pirané', 34056),
(34056050, 'Villa Kilómetro 213', 34056),
(34063010, 'El Potrillo', 34063),
(34063020, 'General Mosconi', 34063),
(34063030, 'El Quebracho', 34063),
(38007020, 'Abra Pampa', 38007),
(38007030, 'Abralaite', 38007),
(38007035, 'Agua de Castilla', 38007),
(38007040, 'Casabindo', 38007),
(38007050, 'Cochinoca', 38007),
(38007055, 'La Redonda', 38007),
(38007060, 'Puesto del Marquéz', 38007),
(38007063, 'Quebraleña', 38007),
(38007067, 'Quera', 38007),
(38007070, 'Rinconadillas', 38007),
(38007080, 'San Francisco de Alfarcito', 38007),
(38007085, 'Santa Ana de la Puna', 38007),
(38007090, 'Santuario de Tres Pozos', 38007),
(38007095, 'Tambillos', 38007),
(38007100, 'Tusaquillas', 38007),
(38014010, 'Aguas Calientes', 38014),
(38014020, 'Barrio El Milagro', 38014),
(38014030, 'Barrio La Unión', 38014),
(38014040, 'El Carmen', 38014),
(38014050, 'Los Lapachos', 38014),
(38014060, 'Manantiales', 38014),
(38014070, 'Monterrico', 38014),
(38014080, 'Pampa Blanca', 38014),
(38014090, 'Perico', 38014),
(38014100, 'Puesto Viejo', 38014),
(38014110, 'San Isidro', 38014),
(38014120, 'San Juancito', 38014),
(38021010, 'Guerrero', 38021),
(38021020, 'La Almona', 38021),
(38021030, 'León', 38021),
(38021040, 'Lozano', 38021),
(38021050, 'Ocloyas', 38021),
(38021060, 'San Salvador de Jujuy', 38021),
(38021065, 'Tesorero', 38021),
(38021070, 'Yala', 38021),
(38028003, 'Aparzo', 38028),
(38028007, 'Cianzo', 38028),
(38028010, 'Coctaca', 38028),
(38028020, 'El Aguilar', 38028),
(38028030, 'Hipólito Yrigoyen', 38028),
(38028040, 'Humahuaca', 38028),
(38028043, 'Palca de Aparzo', 38028),
(38028045, 'Palca de Varas', 38028),
(38028047, 'Rodero', 38028),
(38028050, 'Tres Cruces', 38028),
(38028060, 'Uquía', 38028),
(38035010, 'Bananal', 38035),
(38035020, 'Bermejito', 38035),
(38035030, 'Caimancito', 38035),
(38035040, 'Calilegua', 38035),
(38035050, 'Chalicán', 38035),
(38035060, 'Fraile Pintado', 38035),
(38035070, 'Libertad', 38035),
(38035080, 'Libertador General San Martín', 38035),
(38035090, 'Maíz Negro', 38035),
(38035100, 'Paulina', 38035),
(38035110, 'Yuto', 38035),
(38042010, 'Carahunco', 38042),
(38042020, 'Centro Forestal', 38042),
(38042040, 'Palpalá', 38042),
(38049003, 'Casa Colorada', 38049),
(38049007, 'Coyaguaima', 38049),
(38049010, 'Lagunillas de Farallón', 38049),
(38049020, 'Liviara', 38049),
(38049025, 'Loma Blanca', 38049),
(38049030, 'Nuevo Pirquitas', 38049),
(38049035, 'Orosmayo', 38049),
(38049040, 'Rinconada', 38049),
(38056010, 'El Ceibal', 38056),
(38056017, 'Los Alisos', 38056),
(38056020, 'Loteo Navea', 38056),
(38056025, 'Nuestra Señora del Rosario', 38056),
(38056030, 'San Antonio', 38056),
(38063010, 'Arrayanal', 38063),
(38063020, 'Arroyo Colorado', 38063),
(38063030, 'Don Emilio', 38063),
(38063040, 'El Acheral', 38063),
(38063050, 'El Puesto', 38063),
(38063060, 'El Quemado', 38063),
(38063070, 'La Esperanza', 38063),
(38063080, 'La Manga', 38063),
(38063090, 'La Mendieta', 38063),
(38063110, 'Palos Blancos', 38063),
(38063130, 'Piedritas', 38063),
(38063140, 'Rodeito', 38063),
(38063150, 'Rosario de Río Grande (ex Barro Negro)', 38063),
(38063160, 'San Antonio', 38063),
(38063170, 'San Lucas', 38063),
(38063180, 'San Pedro', 38063),
(38070010, 'El Fuerte', 38070),
(38070020, 'El Piquete', 38070),
(38070030, 'El Talar', 38070),
(38070040, 'Palma Sola', 38070),
(38070050, 'Puente Lavayén', 38070),
(38070060, 'Santa Clara', 38070),
(38070070, 'Vinalito', 38070),
(38077010, 'Casira', 38077),
(38077020, 'Ciénega de Paicone', 38077),
(38077030, 'Cieneguillas', 38077),
(38077040, 'Cusi Cusi', 38077),
(38077045, 'El Angosto', 38077),
(38077050, 'La Ciénega', 38077),
(38077060, 'Misarrumi', 38077),
(38077070, 'Oratorio', 38077),
(38077080, 'Paicone', 38077),
(38077090, 'San Juan de Oros', 38077),
(38077100, 'Santa Catalina', 38077),
(38077110, 'Yoscaba', 38077),
(38084010, 'Catua', 38084),
(38084020, 'Coranzuli', 38084),
(38084030, 'El Toro', 38084),
(38084040, 'Huáncar', 38084),
(38084045, 'Jama', 38084),
(38084050, 'Mina Providencia', 38084),
(38084055, 'Olacapato', 38084),
(38084060, 'Olaroz Chico', 38084),
(38084070, 'Pastos Chicos', 38084),
(38084080, 'Puesto Sey', 38084),
(38084090, 'San Juan de Quillaqués', 38084),
(38084100, 'Susques', 38084),
(38094010, 'Colonia San José', 38094),
(38094020, 'Huacalera', 38094),
(38094030, 'Juella', 38094),
(38094040, 'Maimará', 38094),
(38094050, 'Tilcara', 38094),
(38098010, 'Bárcena', 38098),
(38098020, 'El Moreno', 38098),
(38098025, 'Puerta de Colorados', 38098),
(38098030, 'Purmamarca', 38098),
(38098040, 'Tumbaya', 38098),
(38098050, 'Volcán', 38098),
(38105010, 'Caspalá', 38105),
(38105020, 'Pampichuela', 38105),
(38105030, 'San Francisco', 38105),
(38105040, 'Santa Ana', 38105),
(38105050, 'Valle Colorado', 38105),
(38105060, 'Valle Grande', 38105),
(38112010, 'Barrios', 38112),
(38112020, 'Cangrejillos', 38112),
(38112030, 'El Cóndor', 38112),
(38112040, 'La Intermedia', 38112),
(38112050, 'La Quiaca', 38112),
(38112060, 'Llulluchayoc', 38112),
(38112070, 'Pumahuasi', 38112),
(38112080, 'Yavi', 38112),
(38112090, 'Yavi Chico', 38112),
(42007010, 'Doblas', 42007),
(42007020, 'Macachín', 42007),
(42007030, 'Miguel Riglos', 42007),
(42007040, 'Rolón', 42007),
(42007050, 'Tomás M. Anchorena', 42007),
(42014010, 'Anzoátegui', 42014),
(42014020, 'La Adela', 42014),
(42021010, 'Anguil', 42021),
(42021020, 'Santa Rosa', 42021),
(42028010, 'Catriló', 42028),
(42028020, 'La Gloria', 42028),
(42028030, 'Lonquimay', 42028),
(42028040, 'Uriburu', 42028),
(42035010, 'Conhelo', 42035),
(42035020, 'Eduardo Castex', 42035),
(42035030, 'Mauricio Mayer', 42035),
(42035040, 'Monte Nievas', 42035),
(42035050, 'Rucanelo', 42035),
(42035060, 'Winifreda', 42035),
(42042010, 'Gobernador Duval', 42042),
(42042020, 'Puelches', 42042),
(42049010, 'Santa Isabel', 42049),
(42056010, 'Bernardo Larroude', 42056),
(42056020, 'Ceballos', 42056),
(42056030, 'Coronel Hilario Lagos', 42056),
(42056040, 'Intendente Alvear', 42056),
(42056050, 'Sarah', 42056),
(42056060, 'Vértiz', 42056),
(42063010, 'Algarrobo del Águila', 42063),
(42063020, 'La Humada', 42063),
(42070010, 'Alpachiri', 42070),
(42070020, 'General Manuel J. Campos', 42070),
(42070030, 'Guatraché', 42070),
(42070040, 'Perú', 42070),
(42070050, 'Santa Teresa', 42070),
(42077010, 'Abramo', 42077),
(42077020, 'Bernasconi', 42077),
(42077030, 'General San Martín', 42077),
(42077040, 'Hucal', 42077),
(42077050, 'Jacinto Aráuz', 42077),
(42084010, 'Cuchillo Co', 42084),
(42091010, 'La Reforma', 42091),
(42091020, 'Limay Mahuida', 42091),
(42098010, 'Carro Quemado', 42098),
(42098020, 'Loventué', 42098),
(42098030, 'Luan Toro', 42098),
(42098040, 'Telén', 42098),
(42098050, 'Victorica', 42098),
(42105010, 'Agustoni', 42105),
(42105020, 'Dorila', 42105),
(42105030, 'General Pico', 42105),
(42105040, 'Speluzzi', 42105),
(42105050, 'Trebolares', 42105),
(42112005, 'Casa de Piedra', 42112),
(42112010, 'Puelén', 42112),
(42112020, '25 de Mayo', 42112),
(42119010, 'Colonia Barón', 42119),
(42119020, 'Colonia San José', 42119),
(42119030, 'Miguel Cané', 42119),
(42119040, 'Quemú Quemú', 42119),
(42119050, 'Relmo', 42119),
(42119060, 'Villa Mirasol', 42119),
(42126010, 'Caleufú', 42126),
(42126020, 'Ingeniero Foster', 42126),
(42126030, 'La Maruja', 42126),
(42126040, 'Parera', 42126),
(42126050, 'Pichi Huinca', 42126),
(42126060, 'Quetrequén', 42126),
(42126070, 'Rancul', 42126),
(42133010, 'Adolfo Van Praet', 42133),
(42133020, 'Alta Italia', 42133),
(42133030, 'Damián Maisonave', 42133),
(42133040, 'Embajador Martini', 42133),
(42133050, 'Falucho', 42133),
(42133060, 'Ingeniero Luiggi', 42133),
(42133070, 'Ojeda', 42133),
(42133080, 'Realicó', 42133),
(42140005, 'Cachirulo', 42140),
(42140010, 'Naicó', 42140),
(42140020, 'Toay', 42140),
(42147010, 'Arata', 42147),
(42147020, 'Metileo', 42147),
(42147030, 'Trenel', 42147),
(42154010, 'Ataliva Roca', 42154),
(42154020, 'Chacharramendi', 42154),
(42154030, 'Colonia Santa María', 42154),
(42154040, 'General Acha', 42154),
(42154050, 'Quehué', 42154),
(42154060, 'Unanué', 42154),
(46007010, 'Aimogasta', 46007),
(46007030, 'Bañado de los Pantanos', 46007),
(46007040, 'Estación Mazán', 46007),
(46007045, 'Termas de Santa Teresita', 46007),
(46007050, 'Villa Mazán', 46007),
(46014010, 'La Rioja', 46014),
(46021010, 'Aminga', 46021),
(46021020, 'Anillaco', 46021),
(46021030, 'Anjullón', 46021),
(46021040, 'Chuquis', 46021),
(46021050, 'Los Molinos', 46021),
(46021060, 'Pinchas', 46021),
(46021070, 'San Pedro', 46021),
(46021080, 'Santa Vera Cruz', 46021),
(46028010, 'Aicuñá', 46028),
(46028020, 'Guandacol', 46028),
(46028030, 'Los Palacios', 46028),
(46028040, 'Pagancillo', 46028),
(46028050, 'Villa Unión', 46028),
(46035010, 'Chamical', 46035),
(46035020, 'Polco', 46035),
(46042010, 'Chilecito', 46042),
(46042020, 'Colonia Anguinán', 46042),
(46042040, 'Colonia Malligasta', 46042),
(46042050, 'Colonia Vichigasta', 46042),
(46042060, 'Guanchín', 46042),
(46042070, 'Malligasta', 46042),
(46042080, 'Miranda', 46042),
(46042090, 'Nonogasta', 46042),
(46042100, 'San Nicolás', 46042),
(46042110, 'Santa Florentina', 46042),
(46042120, 'Sañogasta', 46042),
(46042130, 'Tilimuqui', 46042),
(46042140, 'Vichigasta', 46042),
(46049010, 'Alto Carrizal', 46049),
(46049020, 'Angulos', 46049),
(46049030, 'Antinaco', 46049),
(46049040, 'Bajo Carrizal', 46049),
(46049050, 'Campanas', 46049),
(46049060, 'Chañarmuyo', 46049),
(46049070, 'Famatina', 46049),
(46049080, 'La Cuadra', 46049),
(46049090, 'Pituil', 46049),
(46049100, 'Plaza Vieja', 46049),
(46049110, 'Santa Cruz', 46049),
(46049120, 'Santo Domingo', 46049),
(46056010, 'Punta de los Llanos', 46056),
(46056020, 'Tama', 46056),
(46063010, 'Castro Barros', 46063),
(46063020, 'Chañar', 46063),
(46063030, 'Loma Blanca', 46063),
(46063040, 'Olta', 46063),
(46070010, 'Malanzán', 46070),
(46070020, 'Nácate', 46070),
(46070030, 'Portezuelo', 46070),
(46070040, 'San Antonio', 46070),
(46077010, 'Villa Castelli', 46077),
(46084010, 'Ambil', 46084),
(46084020, 'Colonia Ortiz de Ocampo', 46084),
(46084030, 'Milagro', 46084),
(46084040, 'Olpas', 46084),
(46084050, 'Santa Rita de Catuna', 46084),
(46091010, 'Ulapes', 46091),
(46098010, 'Jagüé', 46098),
(46098020, 'Villa San José de Vinchina', 46098),
(46105010, 'Amaná', 46105),
(46105020, 'Patquía', 46105),
(46112010, 'Chepes', 46112),
(46112020, 'Desiderio Tello', 46112),
(46119010, 'Salicas - San Blas', 46119),
(46126010, 'Villa Sanagasta', 46126),
(50007010, 'Mendoza', 50007),
(50014010, 'Bowen', 50014),
(50014020, 'Carmensa', 50014),
(50014030, 'General Alvear', 50014),
(50014040, 'Los Compartos', 50014),
(50021010, 'Godoy Cruz', 50021),
(50028010, 'Colonia Segovia', 50028),
(50028020, 'Guaymallén', 50028),
(50028030, 'La Primavera', 50028),
(50028040, 'Los Corralitos', 50028),
(50028050, 'Puente de Hierro', 50028),
(50035010, 'Ingeniero Giagnoni', 50035),
(50035020, 'Junín', 50035),
(50035030, 'La Colonia', 50035),
(50035040, 'Los Barriales', 50035),
(50035050, 'Medrano', 50035),
(50035060, 'Phillips', 50035),
(50035070, 'Rodríguez Peña', 50035),
(50042010, 'Desaguadero', 50042),
(50042020, 'La Paz', 50042),
(50042030, 'Villa Antigua', 50042),
(50049010, 'Blanco Encalada', 50049),
(50049030, 'Jocolí', 50049),
(50049040, 'Las Cuevas', 50049),
(50049050, 'Las Heras', 50049),
(50049060, 'Los Penitentes', 50049),
(50049080, 'Polvaredas', 50049),
(50049090, 'Puente del Inca', 50049),
(50049100, 'Punta de Vacas', 50049),
(50049110, 'Uspallata', 50049),
(50056010, 'Barrio Alto del Olvido', 50056),
(50056020, 'Barrio Jocolí II', 50056),
(50056030, 'Barrio La Palmera', 50056),
(50056040, 'Barrio La Pega', 50056),
(50056050, 'Barrio Lagunas de Bartoluzzi', 50056),
(50056060, 'Barrio Los Jarilleros', 50056),
(50056070, 'Barrio Los Olivos', 50056),
(50056075, 'Barrio Virgen del Rosario', 50056),
(50056080, 'Costa de Araujo', 50056),
(50056090, 'El Paramillo', 50056),
(50056100, 'El Vergel', 50056),
(50056110, 'Ingeniero Gustavo André', 50056),
(50056120, 'Jocolí', 50056),
(50056130, 'Jocolí Viejo', 50056),
(50056140, 'Las Violetas', 50056),
(50056150, '3 de Mayo', 50056),
(50056160, 'Villa Tulumaya', 50056),
(50063010, 'Agrelo', 50063),
(50063020, 'Barrio Perdriel IV', 50063),
(50063030, 'Cacheuta', 50063),
(50063040, 'Costa Flores', 50063),
(50063050, 'El Carrizal', 50063),
(50063060, 'El Salto', 50063),
(50063070, 'Las Compuertas', 50063),
(50063080, 'Las Vegas', 50063),
(50063090, 'Luján de Cuyo', 50063),
(50063100, 'Perdriel', 50063),
(50063110, 'Potrerillos', 50063),
(50063120, 'Ugarteche', 50063),
(50070010, 'Barrancas', 50070),
(50070020, 'Barrio Jesús de Nazaret', 50070),
(50070030, 'Cruz de Piedra', 50070),
(50070040, 'El Pedregal', 50070),
(50070050, 'Fray Luis Beltrán', 50070),
(50070060, 'Maipú', 50070),
(50070070, 'Rodeo del Medio', 50070),
(50070090, 'San Roque', 50070),
(50070100, 'Villa Teresa', 50070),
(50077010, 'Agua Escondida', 50077),
(50077030, 'Las Leñas', 50077),
(50077040, 'Malargüe', 50077),
(50084010, 'Andrade', 50084),
(50084020, 'Barrio Cooperativa Los Campamentos', 50084),
(50084030, 'Barrio Rivadavia', 50084),
(50084040, 'El Mirador', 50084),
(50084050, 'La Central', 50084),
(50084060, 'La Esperanza', 50084),
(50084070, 'La Florida', 50084),
(50084080, 'La Libertad', 50084),
(50084090, 'Los Árboles', 50084),
(50084100, 'Los Campamentos', 50084),
(50084110, 'Medrano', 50084),
(50084120, 'Mundo Nuevo', 50084),
(50084130, 'Reducción de Abajo', 50084),
(50084140, 'Rivadavia', 50084),
(50084150, 'Santa María de Oro', 50084),
(50091005, 'Barrio Carrasco', 50091),
(50091010, 'Barrio El Cepillo', 50091),
(50091020, 'Chilecito', 50091),
(50091030, 'Eugenio Bustos', 50091),
(50091040, 'La Consulta', 50091),
(50091050, 'Pareditas', 50091),
(50091060, 'San Carlos', 50091),
(50098020, 'Alto Verde', 50098),
(50098030, 'Barrio Chivilcoy', 50098),
(50098040, 'Barrio Emanuel', 50098),
(50098045, 'Barrio La Estación', 50098),
(50098050, 'Barrio Los Charabones', 50098),
(50098055, 'Barrio Ntra. Sra. De Fátima', 50098),
(50098060, 'Chapanay', 50098),
(50098070, 'Chivilcoy', 50098),
(50098073, 'El Espino', 50098),
(50098077, 'El Ramblón', 50098),
(50098080, 'Montecaseros', 50098),
(50098090, 'Nueva California', 50098),
(50098100, 'San Martín', 50098),
(50098110, 'Tres Porteñas', 50098),
(50105020, 'Barrio El Nevado', 50105),
(50105030, 'Barrio Empleados de Comercio', 50105),
(50105040, 'Barrio Intendencia', 50105),
(50105050, 'Capitán Montoya', 50105),
(50105060, 'Cuadro Benegas', 50105),
(50105070, 'El Nihuil', 50105),
(50105080, 'El Sosneado', 50105),
(50105090, 'El Tropezón', 50105),
(50105100, 'Goudge', 50105),
(50105110, 'Jaime Prats', 50105),
(50105120, 'La Llave Nueva', 50105),
(50105130, 'Las Malvinas', 50105),
(50105140, 'Los Reyunos', 50105),
(50105150, 'Monte Comán', 50105),
(50105160, 'Pobre Diablo', 50105),
(50105170, 'Punta del Agua', 50105),
(50105180, 'Rama Caída', 50105),
(50105190, 'Real del Padre', 50105),
(50105200, 'Salto de las Rosas', 50105),
(50105210, 'San Rafael', 50105),
(50105220, '25 de Mayo', 50105),
(50105230, 'Villa Atuel', 50105),
(50105240, 'Villa Atuel Norte', 50105),
(50112010, 'Barrio 12 de Octubre', 50112),
(50112020, 'Barrio María Auxiliadora', 50112),
(50112030, 'Barrio Molina Cabrera', 50112),
(50112040, 'La Dormida', 50112),
(50112050, 'Las Catitas', 50112),
(50112060, 'Santa Rosa', 50112),
(50119010, 'Barrio San Cayetano', 50119),
(50119020, 'Campo Los Andes', 50119),
(50119030, 'Colonia Las Rosas', 50119),
(50119040, 'El Manzano', 50119),
(50119050, 'Los Sauces', 50119),
(50119060, 'Tunuyán', 50119),
(50119070, 'Vista Flores', 50119),
(50126010, 'Barrio Belgrano Norte', 50126),
(50126020, 'Cordón del Plata', 50126),
(50126030, 'El Peral', 50126),
(50126035, 'El Zampal', 50126),
(50126040, 'La Arboleda', 50126),
(50126050, 'San José', 50126),
(50126060, 'Tupungato', 50126),
(54007010, 'Apóstoles', 54007),
(54007020, 'Azara', 54007),
(54007025, 'Barrio Rural', 54007),
(54007030, 'Estación Apóstoles', 54007),
(54007040, 'Pindapoy', 54007),
(54007050, 'Rincón de Azara', 54007),
(54007060, 'San José', 54007),
(54007070, 'Tres Capones', 54007),
(54014010, 'Aristóbulo del Valle', 54014),
(54014020, 'Campo Grande', 54014),
(54014030, 'Dos de Mayo', 54014),
(54014050, 'Dos de Mayo Nucleo III (Bº Bernardino Rivadavia)', 54014),
(54014055, 'Kilómetro 17', 54014),
(54014060, '1º de Mayo', 54014),
(54014070, 'Pueblo Illia', 54014),
(54014080, 'Salto Encantado', 54014),
(54021005, 'Barrio del Lago', 54021),
(54021010, 'Bonpland', 54021),
(54021020, 'Candelaria', 54021),
(54021030, 'Cerro Corá', 54021),
(54021040, 'Loreto', 54021),
(54021050, 'Mártires', 54021),
(54021060, 'Profundidad', 54021),
(54021070, 'Puerto Santa Ana', 54021),
(54021080, 'Santa Ana', 54021),
(54028010, 'Garupá', 54028),
(54028020, 'Nemesio Parma', 54028),
(54028030, 'Posadas', 54028),
(54028040, 'Posadas (Extensión)', 54028),
(54035010, 'Barra Concepción', 54035),
(54035020, 'Concepción de la Sierra', 54035),
(54035030, 'La Corita', 54035),
(54035040, 'Santa María', 54035),
(54042010, 'Colonia Victoria', 54042),
(54042020, 'Eldorado', 54042),
(54042030, 'María Magdalena', 54042),
(54042035, 'Nueva Delicia', 54042),
(54042040, '9 de Julio Kilómetro 28', 54042),
(54042050, '9 de Julio Kilómetro 20', 54042),
(54042055, 'Pueblo Nuevo', 54042),
(54042060, 'Puerto Mado', 54042),
(54042070, 'Puerto Pinares', 54042),
(54042080, 'Santiago de Liniers', 54042),
(54042090, 'Valle Hermoso', 54042),
(54042100, 'Villa Roulet', 54042),
(54049010, 'Comandante Andresito', 54049),
(54049020, 'Bernardo de Irigoyen', 54049),
(54049025, 'Caburei', 54049),
(54049030, 'Dos Hermanas', 54049),
(54049040, 'Integración', 54049),
(54049043, 'Piñalito Norte', 54049),
(54049045, 'Puerto Andresito', 54049),
(54049047, 'Puerto Deseado', 54049),
(54049050, 'San Antonio', 54049),
(54056010, 'El Soberbio', 54056),
(54056020, 'Fracrán', 54056),
(54056030, 'San Vicente', 54056),
(54063010, 'Puerto Esperanza', 54063),
(54063020, 'Puerto Libertad', 54063),
(54063030, 'Puerto Iguazú', 54063),
(54063035, 'Villa Cooperativa', 54063),
(54063040, 'Colonia Wanda', 54063),
(54070010, 'Almafuerte', 54070),
(54070020, 'Arroyo del Medio', 54070),
(54070030, 'Caá - Yarí', 54070),
(54070040, 'Cerro Azul', 54070),
(54070050, 'Dos Arroyos', 54070),
(54070060, 'Gobernador López', 54070),
(54070070, 'Leandro N. Alem', 54070),
(54070080, 'Olegario V. Andrade', 54070),
(54070090, 'Villa Libertad', 54070),
(54077010, 'Capioví', 54077),
(54077015, 'Capioviciño', 54077),
(54077020, 'El Alcázar', 54077),
(54077030, 'Garuhapé', 54077),
(54077040, 'Mbopicuá', 54077),
(54077050, 'Puerto Leoni', 54077),
(54077060, 'Puerto Rico', 54077),
(54077070, 'Ruiz de Montoya', 54077),
(54077080, 'San Alberto', 54077),
(54077090, 'San Gotardo', 54077),
(54077100, 'San Miguel', 54077),
(54077110, 'Villa Akerman', 54077),
(54077120, 'Villa Urrutia', 54077),
(54084003, 'Barrio Cuatro Bocas', 54084),
(54084005, 'Barrio Guatambu', 54084),
(54084007, 'Bario Ita', 54084),
(54084010, 'Caraguatay', 54084),
(54084020, 'Laharrague', 54084),
(54084030, 'Montecarlo', 54084),
(54084040, 'Piray Kilómetro 18', 54084),
(54084050, 'Puerto Piray', 54084),
(54084060, 'Tarumá', 54084),
(54084070, 'Villa Parodi', 54084),
(54091010, 'Colonia Alberdi', 54091),
(54091013, 'Barrio Escuela 461', 54091),
(54091017, 'Barrio Escuela 633', 54091),
(54091020, 'Campo Ramón', 54091),
(54091030, 'Campo Viera', 54091),
(54091040, 'El Salto', 54091),
(54091050, 'General Alvear', 54091),
(54091060, 'Guaraní', 54091),
(54091070, 'Los Helechos', 54091),
(54091080, 'Oberá', 54091),
(54091090, 'Panambí', 54091),
(54091100, 'Panambí Kilómetro 8', 54091),
(54091105, 'Panambi Kilómetro 15', 54091),
(54091110, 'San Martín', 54091),
(54091120, 'Villa Bonita', 54091),
(54098005, 'Barrio Tungoil', 54098),
(54098010, 'Colonia Polana', 54098),
(54098020, 'Corpus', 54098),
(54098030, 'Domingo Savio', 54098),
(54098040, 'General Urquiza', 54098),
(54098050, 'Gobernador Roca', 54098),
(54098060, 'Helvecia', 54098),
(54098070, 'Hipólito Yrigoyen', 54098),
(54098080, 'Jardín América', 54098),
(54098090, 'Oasis', 54098),
(54098100, 'Roca Chica', 54098),
(54098110, 'San Ignacio', 54098),
(54098120, 'Santo Pipó', 54098),
(54105010, 'Florentino Ameghino', 54105),
(54105020, 'Itacaruaré', 54105),
(54105030, 'Mojón Grande', 54105),
(54105040, 'San Javier', 54105),
(54112010, 'Cruce Caballero', 54112),
(54112020, 'Paraíso', 54112),
(54112030, 'Piñalito Sur', 54112),
(54112040, 'San Pedro', 54112),
(54112050, 'Tobuna', 54112),
(54119010, 'Alba Posse', 54119),
(54119020, 'Alicia Alta', 54119),
(54119025, 'Alicia Baja', 54119),
(54119030, 'Colonia Aurora', 54119),
(54119040, 'San Francisco de Asís', 54119),
(54119050, 'Santa Rita', 54119),
(54119060, '25 de Mayo', 54119),
(58007010, 'Aluminé', 58007),
(58007015, 'Moquehue', 58007),
(58007020, 'Villa Pehuenia', 58007),
(58014005, 'Aguada San Roque', 58014),
(58014010, 'Añelo', 58014),
(58014020, 'San Patricio del Chañar', 58014),
(58021010, 'Las Coloradas', 58021),
(58028010, 'Piedra del Águila', 58028),
(58028020, 'Santo Tomás', 58028),
(58035010, 'Arroyito', 58035),
(58035030, 'Centenario', 58035),
(58035040, 'Cutral Có', 58035),
(58035060, 'Mari Menuco', 58035),
(58035070, 'Neuquén', 58035),
(58035090, 'Plaza Huincul', 58035),
(58035100, 'Plottier', 58035),
(58035110, 'Senillosa', 58035),
(58035120, 'Villa El Chocón', 58035),
(58035130, 'Vista Alegre Norte', 58035),
(58035140, 'Vista Alegre Sur', 58035),
(58042010, 'Chos Malal', 58042),
(58042020, 'Tricao Malal', 58042),
(58042030, 'Villa del Curi Leuvú', 58042),
(58049010, 'Junín de los Andes', 58049),
(58056010, 'San Martín de los Andes', 58056),
(58056020, 'Villa Lago Meliquina', 58056),
(58063010, 'Chorriaca', 58063),
(58063020, 'Loncopué', 58063),
(58070010, 'Villa La Angostura', 58070),
(58070020, 'Villa Traful', 58070),
(58077010, 'Andacollo', 58077),
(58077020, 'Huinganco', 58077),
(58077030, 'Las Ovejas', 58077),
(58077040, 'Los Miches', 58077),
(58077050, 'Manzano Amargo', 58077),
(58077060, 'Varvarco', 58077),
(58077070, 'Villa del Nahueve', 58077),
(58084010, 'Caviahue', 58084),
(58084020, 'Copahue', 58084),
(58084030, 'El Cholar', 58084),
(58084040, 'El Huecú', 58084),
(58084050, 'Taquimilán', 58084),
(58091010, 'Barrancas', 58091),
(58091020, 'Buta Ranquil', 58091),
(58091030, 'Octavio Pico', 58091),
(58091040, 'Rincón de los Sauces', 58091),
(58098005, 'El Sauce', 58098),
(58098010, 'Paso Aguerre', 58098),
(58098020, 'Picún Leufú', 58098),
(58105010, 'Bajada del Agrio', 58105),
(58105020, 'La Buitrera', 58105),
(58105030, 'Las Lajas', 58105),
(58105040, 'Quili Malal', 58105),
(58112010, 'Los Catutos', 58112),
(58112020, 'Mariano Moreno', 58112),
(58112030, 'Ramón M. Castro', 58112),
(58112040, 'Zapala', 58112),
(62007010, 'Bahía Creek', 62007),
(62007020, 'El Cóndor', 62007),
(62007030, 'El Juncal', 62007),
(62007040, 'Guardia Mitre', 62007),
(62007050, 'La Lobería', 62007),
(62007060, 'Loteo Costa de Río', 62007),
(62007070, 'Pozo Salado', 62007),
(62007080, 'San Javier', 62007),
(62007090, 'Viedma', 62007),
(62014010, 'Barrio Unión', 62014),
(62014020, 'Chelforó', 62014),
(62014030, 'Chimpay', 62014),
(62014040, 'Choele Choel', 62014),
(62014050, 'Coronel Belisle', 62014),
(62014060, 'Darwin', 62014),
(62014070, 'Lamarque', 62014),
(62014080, 'Luis Beltrán', 62014),
(62014090, 'Pomona', 62014),
(62021020, 'Colonia Suiza', 62021),
(62021030, 'El Bolsón', 62021),
(62021040, 'El Foyel', 62021),
(62021047, 'Mallín Ahogado', 62021),
(62021050, 'Río Villegas', 62021),
(62021060, 'San Carlos de Bariloche', 62021),
(62021080, 'Villa Catedral', 62021),
(62021110, 'Villa Mascardi', 62021),
(62028010, 'Barrio Colonia Conesa', 62028),
(62028020, 'General Conesa', 62028),
(62028030, 'Barrio Planta Compresora de Gas', 62028),
(62035010, 'Aguada Guzmán', 62035),
(62035020, 'Cerro Policía', 62035),
(62035030, 'El Cuy', 62035),
(62035040, 'Las Perlas', 62035),
(62035050, 'Mencué', 62035),
(62035060, 'Naupa Huen', 62035),
(62035070, 'Paso Córdova', 62035),
(62035080, 'Valle Azul', 62035),
(62042010, 'Allen', 62042),
(62042020, 'Paraje Arroyón (Bajo San Cayetano)', 62042),
(62042030, 'Barda del Medio', 62042),
(62042040, 'Barrio Blanco', 62042),
(62042050, 'Barrio Calle Ciega Nº 10', 62042),
(62042060, 'Barrio Calle Ciega Nº 6', 62042),
(62042070, 'Barrio Canale', 62042),
(62042080, 'Barrio Chacra Monte', 62042),
(62042090, 'Barrio Costa Este', 62042),
(62042110, 'Barrio Costa Oeste', 62042),
(62042115, 'Barrio Destacamento', 62042),
(62042120, 'Barrio El Labrador', 62042),
(62042130, 'Barrio El Maruchito', 62042),
(62042140, 'Barrio El Petróleo', 62042),
(62042143, 'Barrio Emergente', 62042),
(62042147, 'Barrio Fátima', 62042),
(62042150, 'Barrio Frontera', 62042),
(62042160, 'Barrio Guerrico', 62042),
(62042170, 'Barrio Isla 10', 62042),
(62042180, 'Barrio La Barda', 62042),
(62042200, 'Barrio La Costa', 62042),
(62042210, 'Barrio La Defensa', 62042),
(62042215, 'Barrio La Herradura', 62042),
(62042240, 'Puente Cero', 62042),
(62042245, 'Barrio Luisillo', 62042),
(62042250, 'Barrio Mar del Plata', 62042),
(62042260, 'Barrio María Elvira', 62042),
(62042265, 'Barrio Moño Azul', 62042),
(62042280, 'Barrio Norte', 62042),
(62042297, 'Barrio Pinar', 62042),
(62042310, 'Barrio Porvenir', 62042),
(62042335, 'Barrio Santa Lucia', 62042),
(62042340, 'Barrio Santa Rita', 62042),
(62042350, 'Barrio Unión', 62042),
(62042360, 'Catriel', 62042),
(62042370, 'Cervantes', 62042),
(62042380, 'Chichinales', 62042),
(62042390, 'Cinco Saltos', 62042),
(62042400, 'Cipolletti', 62042),
(62042410, 'Contralmirante Cordero', 62042),
(62042420, 'Ferri', 62042),
(62042430, 'General Enrique Godoy', 62042),
(62042440, 'General Fernández Oro', 62042),
(62042450, 'General Roca', 62042),
(62042460, 'Ingeniero Luis A. Huergo', 62042),
(62042470, 'Ingeniero Otto Krause', 62042),
(62042480, 'Mainqué', 62042),
(62042490, 'Paso Córdova', 62042),
(62042500, 'Península Ruca Co', 62042),
(62042520, 'Sargento Vidal', 62042),
(62042530, 'Villa Alberdi', 62042),
(62042540, 'Villa del Parque', 62042),
(62042550, 'Villa Manzano', 62042),
(62042560, 'Villa Regina', 62042),
(62042570, 'Villa San Isidro', 62042),
(62049010, 'Comicó', 62049),
(62049020, 'Cona Niyeu', 62049),
(62049030, 'Ministro Ramos Mexía', 62049),
(62049040, 'Prahuaniyeu', 62049),
(62049050, 'Sierra Colorada', 62049),
(62049060, 'Treneta', 62049),
(62049070, 'Yaminué', 62049),
(62056010, 'Las Bayas', 62056),
(62056020, 'Mamuel Choique', 62056),
(62056030, 'Ñorquincó', 62056),
(62056040, 'Ojos de Agua', 62056),
(62056050, 'Río Chico', 62056),
(62063005, 'Barrio Esperanza', 62063),
(62063010, 'Colonia Juliá y Echarren', 62063),
(62063013, 'Juventud Unida', 62063),
(62063017, 'Pichi Mahuida', 62063),
(62063020, 'Río Colorado', 62063),
(62063060, 'Salto Andersen', 62063),
(62070005, 'Cañadón Chileno', 62070),
(62070010, 'Comallo', 62070),
(62070020, 'Dina Huapi', 62070),
(62070030, 'Laguna Blanca', 62070),
(62070040, 'Ñirihuau', 62070),
(62070060, 'Pilcaniyeu', 62070),
(62070070, 'Pilquiniyeu del Limay', 62070),
(62070080, 'Villa Llanquín', 62070),
(62077005, 'El Empalme', 62077),
(62077010, 'Las Grutas', 62077),
(62077020, 'Playas Doradas', 62077),
(62077030, 'Puerto San Antonio Este', 62077),
(62077040, 'Punta Colorada', 62077),
(62077045, 'Saco Viejo', 62077),
(62077050, 'San Antonio Oeste', 62077),
(62077060, 'Sierra Grande', 62077),
(62084010, 'Aguada Cecilio', 62084),
(62084020, 'Arroyo Los Berros', 62084),
(62084030, 'Arroyo Ventana', 62084),
(62084040, 'Nahuel Niyeu', 62084),
(62084050, 'Sierra Pailemán', 62084),
(62084060, 'Valcheta', 62084),
(62091010, 'Aguada de Guerra', 62091),
(62091020, 'Clemente Onelli', 62091),
(62091030, 'Colan Conhue', 62091),
(62091040, 'El Caín', 62091),
(62091050, 'Ingeniero Jacobacci', 62091),
(62091060, 'Los Menucos', 62091),
(62091070, 'Maquinchao', 62091),
(62091090, 'Pilquiniyeu', 62091),
(66007010, 'Apolinario Saravia', 66007),
(66007020, 'Ceibalito', 66007),
(66007030, 'Centro 25 de Junio', 66007),
(66007040, 'Coronel Mollinedo', 66007),
(66007050, 'Coronel Olleros', 66007),
(66007060, 'El Quebrachal', 66007),
(66007070, 'Gaona', 66007),
(66007080, 'General Pizarro', 66007),
(66007090, 'Joaquín V. González', 66007),
(66007100, 'Las Lajitas', 66007),
(66007110, 'Luis Burela', 66007),
(66007120, 'Macapillo', 66007),
(66007130, 'Nuestra Señora de Talavera', 66007),
(66007140, 'Piquete Cabado', 66007),
(66007150, 'Río del Valle', 66007),
(66007160, 'Tolloche', 66007),
(66014010, 'Cachi', 66014),
(66014020, 'Payogasta', 66014),
(66021010, 'Cafayate', 66021),
(66021020, 'Tolombón', 66021),
(66028050, 'Salta', 66028),
(66028060, 'Villa San Lorenzo', 66028),
(66035010, 'Cerrillos', 66035),
(66035020, 'La Merced', 66035),
(66035030, 'San Agustín', 66035),
(66042003, 'Barrio Finca La Maroma', 66042),
(66042005, 'Barrio La Rotonda', 66042),
(66042007, 'Barrio Santa Teresita', 66042),
(66042010, 'Chicoana', 66042),
(66042020, 'El Carril', 66042),
(66049010, 'Campo Santo', 66049),
(66049020, 'Cobos', 66049),
(66049030, 'El Bordo', 66049),
(66049040, 'General Güemes', 66049),
(66056010, 'Aguaray', 66056),
(66056030, 'Campichuelo', 66056),
(66056040, 'Campo Durán', 66056),
(66056050, 'Capiazuti', 66056),
(66056060, 'Carboncito', 66056),
(66056070, 'Coronel Cornejo', 66056),
(66056080, 'Dragones', 66056),
(66056090, 'Embarcación', 66056),
(66056100, 'General Ballivián', 66056),
(66056110, 'General Mosconi', 66056),
(66056120, 'Hickman', 66056),
(66056130, 'Misión Chaqueña', 66056),
(66056150, 'Misión Kilómetro 6', 66056),
(66056170, 'Pacará', 66056),
(66056180, 'Padre Lozano', 66056),
(66056190, 'Piquirenda', 66056),
(66056200, 'Profesor Salvador Mazza', 66056),
(66056220, 'Tartagal', 66056),
(66056230, 'Tobantirenda', 66056),
(66056240, 'Tranquitas', 66056),
(66056250, 'Yacuy', 66056),
(66063010, 'Guachipas', 66063),
(66070010, 'Iruya', 66070),
(66070020, 'Isla de Cañas', 66070),
(66070030, 'Pueblo Viejo', 66070),
(66077010, 'La Caldera', 66077),
(66077020, 'Vaqueros', 66077),
(66084010, 'El Jardín', 66084),
(66084020, 'El Tala', 66084),
(66084030, 'La Candelaria', 66084),
(66091010, 'Cobres', 66091),
(66091020, 'La Poma', 66091),
(66098010, 'Ampascachi', 66098),
(66098020, 'Cabra Corral', 66098),
(66098030, 'Coronel Moldes', 66098),
(66098040, 'La Viña', 66098),
(66098050, 'Talapampa', 66098),
(66105010, 'Olacapato', 66105),
(66105020, 'San Antonio de los Cobres', 66105),
(66105030, 'Santa Rosa de los Pastos Grandes', 66105),
(66105040, 'Tolar Grande', 66105),
(66112010, 'El Galpón', 66112),
(66112020, 'El Tunal', 66112),
(66112030, 'Lumbreras', 66112),
(66112040, 'San José de Metán (Est. Metán)', 66112),
(66112070, 'Río Piedras', 66112),
(66112080, 'San José de Orquera', 66112),
(66119010, 'La Puerta', 66119),
(66119020, 'Molinos', 66119),
(66119030, 'Seclantás', 66119),
(66126010, 'Aguas Blancas', 66126),
(66126020, 'Colonia Santa Rosa', 66126),
(66126030, 'El Tabacal', 66126),
(66126040, 'Hipólito Yrigoyen', 66126),
(66126060, 'Pichanal', 66126),
(66126070, 'San Ramón de la Nueva Orán', 66126),
(66126080, 'Urundel', 66126),
(66133010, 'Alto de la Sierra', 66133),
(66133020, 'Capitán Juan Pagé', 66133),
(66133030, 'Coronel Juan Solá', 66133),
(66133035, 'Hito 1', 66133),
(66133040, 'La Unión', 66133),
(66133050, 'Los Blancos', 66133),
(66133060, 'Pluma de Pato', 66133),
(66133070, 'Rivadavia', 66133),
(66133080, 'Santa María', 66133),
(66133090, 'Santa Rosa', 66133),
(66133100, 'Santa Victoria Este', 66133),
(66140010, 'Antillá', 66140),
(66140020, 'Copo Quile', 66140),
(66140030, 'El Naranjo', 66140),
(66140040, 'El Potrero', 66140),
(66140050, 'Rosario de la Frontera', 66140),
(66140060, 'San Felipe', 66140),
(66147010, 'Campo Quijano', 66147),
(66147015, 'La Merced del Encón', 66147),
(66147020, 'La Silleta', 66147),
(66147030, 'Rosario de Lerma', 66147),
(66154010, 'Angastaco', 66154),
(66154020, 'Animaná', 66154),
(66154040, 'San Carlos', 66154),
(66161010, 'Acoyte', 66161),
(66161020, 'Campo La Cruz', 66161),
(66161030, 'Los Toldos', 66161),
(66161040, 'Nazareno', 66161),
(66161050, 'Poscaya', 66161),
(66161060, 'San Marcos', 66161),
(66161070, 'Santa Victoria', 66161),
(70007010, 'El Rincón', 70007),
(70007020, 'Villa General San Martín - Campo Afuera', 70007),
(70014010, 'Las Tapias', 70014),
(70014020, 'Villa El Salvador - Villa Sefair', 70014),
(70021010, 'Barreal - Villa Pituil', 70021),
(70021020, 'Calingasta', 70021),
(70021030, 'Tamberías', 70021),
(70028010, 'San Juan', 70028),
(70035010, 'Bermejo', 70035),
(70035020, 'Caucete', 70035),
(70035030, 'El Rincón', 70035),
(70035040, 'Las Talas - Los Médanos', 70035),
(70035050, 'Marayes', 70035),
(70035060, 'Pie de Palo', 70035),
(70035070, 'Vallecito', 70035),
(70035080, 'Villa Independencia', 70035),
(70042010, 'Chimbas', 70042),
(70049010, 'Angualasto', 70049),
(70049030, 'Iglesia', 70049),
(70049040, 'Las Flores', 70049),
(70049050, 'Pismanta', 70049),
(70049060, 'Rodeo', 70049),
(70049070, 'Tudcum', 70049),
(70056010, 'El Médano', 70056),
(70056020, 'Gran China', 70056),
(70056030, 'Huaco', 70056),
(70056040, 'Mogna', 70056),
(70056050, 'Niquivil', 70056),
(70056060, 'Pampa Vieja', 70056),
(70056070, 'San Isidro', 70056),
(70056080, 'San José de Jáchal', 70056),
(70056090, 'Tamberías', 70056),
(70056100, 'Villa Malvinas Argentinas', 70056),
(70056110, 'Villa Mercedes', 70056),
(70063010, 'Alto de Sierra', 70063),
(70063030, 'Las Chacritas', 70063),
(70063040, '9 de Julio', 70063),
(70070005, 'Barrio Municipal', 70070),
(70070010, 'Barrio Ruta 40', 70070),
(70070020, 'Carpintería', 70070),
(70070030, 'Quinto Cuartel', 70070),
(70070040, 'Villa Aberastain - La Rinconada', 70070),
(70070050, 'Villa Barboza - Villa Nacusi', 70070),
(70070060, 'Villa Centenario', 70070),
(70077010, 'Rawson', 70077),
(70077020, 'Villa Bolaños (Médano de Oro)', 70077),
(70084010, 'Rivadavia', 70084),
(70091010, 'Barrio Sadop - Bella Vista', 70091),
(70091020, 'Dos Acequias', 70091),
(70091030, 'San Isidro', 70091),
(70091040, 'Villa del Salvador', 70091),
(70091050, 'Villa Dominguito', 70091),
(70091060, 'Villa Don Bosco', 70091),
(70091070, 'Villa San Martín', 70091),
(70098010, 'Santa Lucía', 70098),
(70105010, 'Cañada Honda', 70105),
(70105020, 'Cienaguita', 70105),
(70105030, 'Colonia Fiscal', 70105),
(70105040, 'Divisadero', 70105),
(70105060, 'Las Lagunas', 70105),
(70105070, 'Los Berros', 70105),
(70105080, 'Pedernal', 70105),
(70105090, 'Punta del Médano', 70105),
(70105100, 'Villa Media Agua', 70105),
(70112010, 'Villa Ibáñez', 70112),
(70119010, 'Astica', 70119),
(70119020, 'Balde del Rosario', 70119),
(70119030, 'Chucuma', 70119),
(70119040, 'Los Baldecitos', 70119),
(70119050, 'Usno', 70119),
(70119060, 'Villa San Agustín', 70119),
(70126010, 'El Encón', 70126),
(70126020, 'Tupelí', 70126),
(70126030, 'Villa Borjas - La Chimbera', 70126),
(70126040, 'Villa El Tango', 70126),
(70126050, 'Villa Santa Rosa', 70126),
(70133010, 'Villa Basilio Nievas', 70133),
(74007010, 'Candelaria', 74007),
(74007030, 'Leandro N. Alem', 74007),
(74007040, 'Luján', 74007),
(74007050, 'Quines', 74007),
(74007070, 'San Francisco del Monte de Oro', 74007),
(74014010, 'La Calera', 74014),
(74014020, 'Nogolí', 74014),
(74014030, 'Villa de la Quebrada', 74014),
(74014040, 'Villa General Roca', 74014),
(74021010, 'Carolina', 74021),
(74021020, 'El Trapiche', 74021),
(74021025, 'Estancia Grande', 74021),
(74021030, 'Fraga', 74021),
(74021050, 'La Florida', 74021),
(74021060, 'La Toma', 74021),
(74021070, 'Riocito', 74021),
(74021090, 'Saladillo', 74021),
(74028010, 'Concarán', 74028),
(74028020, 'Cortaderas', 74028),
(74028030, 'Naschel', 74028),
(74028040, 'Papagayos', 74028),
(74028050, 'Renca', 74028),
(74028060, 'San Pablo', 74028),
(74028070, 'Tilisarao', 74028),
(74028080, 'Villa del Carmen', 74028),
(74028090, 'Villa Larca', 74028),
(74035010, 'Juan Jorba', 74035),
(74035020, 'Juan Llerena', 74035),
(74035030, 'Justo Daract', 74035),
(74035040, 'La Punilla', 74035),
(74035050, 'Lavaisse', 74035),
(74035055, 'Nación Ranquel', 74035),
(74035060, 'San José del Morro', 74035),
(74035070, 'Villa Mercedes', 74035),
(74035080, 'Villa Reynolds', 74035),
(74035090, 'Villa Salles', 74035),
(74042010, 'Anchorena', 74042),
(74042020, 'Arizona', 74042),
(74042030, 'Bagual', 74042),
(74042040, 'Batavia', 74042),
(74042050, 'Buena Esperanza', 74042),
(74042060, 'Fortín El Patria', 74042),
(74042070, 'Fortuna', 74042),
(74042080, 'La Maroma', 74042),
(74042090, 'Los Overos', 74042),
(74042100, 'Martín de Loyola', 74042),
(74042110, 'Nahuel Mapá', 74042),
(74042120, 'Navia', 74042),
(74042130, 'Nueva Galia', 74042),
(74042140, 'Unión', 74042),
(74049010, 'Carpintería', 74049),
(74049030, 'Lafinur', 74049),
(74049040, 'Los Cajones', 74049),
(74049050, 'Los Molles', 74049),
(74049060, 'Merlo', 74049),
(74049070, 'Santa Rosa del Conlara', 74049),
(74049080, 'Talita', 74049),
(74056010, 'Alto Pelado', 74056),
(74056020, 'Alto Pencoso', 74056),
(74056030, 'Balde', 74056),
(74056040, 'Beazley', 74056),
(74056050, 'Cazador', 74056),
(74056060, 'Chosmes', 74056),
(74056070, 'Desaguadero', 74056),
(74056080, 'El Volcán', 74056),
(74056090, 'Jarilla', 74056),
(74056100, 'Juana Koslay', 74056),
(74056105, 'La Punta', 74056),
(74056110, 'Mosmota', 74056),
(74056120, 'Potrero de los Funes', 74056),
(74056130, 'Salinas del Bebedero', 74056),
(74056140, 'San Jerónimo', 74056),
(74056150, 'San Luis', 74056),
(74056160, 'Zanjitas', 74056),
(74063010, 'La Vertiente', 74063),
(74063020, 'Las Aguadas', 74063),
(74063030, 'Las Chacras', 74063),
(74063040, 'Las Lagunas', 74063),
(74063050, 'Paso Grande', 74063),
(74063060, 'Potrerillo', 74063),
(74063070, 'San Martín', 74063),
(74063080, 'Villa de Praga', 74063),
(78007010, 'Comandante Luis Piedrabuena', 78007),
(78007020, 'Puerto Santa Cruz', 78007),
(78014010, 'Caleta Olivia', 78014),
(78014020, 'Cañadón Seco', 78014),
(78014030, 'Fitz Roy', 78014),
(78014040, 'Jaramillo', 78014),
(78014050, 'Koluel Kaike', 78014),
(78014060, 'Las Heras', 78014),
(78014070, 'Pico Truncado', 78014),
(78014080, 'Puerto Deseado', 78014),
(78014090, 'Tellier', 78014),
(78021010, 'El Turbio', 78021),
(78021020, 'Julia Dufour', 78021),
(78021040, 'Río Gallegos', 78021),
(78021050, 'Rospentek', 78021),
(78021060, '28 de Noviembre', 78021),
(78021070, 'Yacimientos Río Turbio', 78021),
(78028010, 'El Calafate', 78028),
(78028020, 'El Chaltén', 78028),
(78028030, 'Tres Lagos', 78028),
(78035010, 'Los Antiguos', 78035),
(78035020, 'Perito Moreno', 78035),
(78042010, 'Puerto San Julián', 78042),
(78049010, 'Bajo Caracoles', 78049),
(78049020, 'Gobernador Gregores', 78049),
(78049030, 'Hipólito Yrigoyen', 78049),
(82007010, 'Armstrong', 82007),
(82007020, 'Bouquet', 82007),
(82007030, 'Las Parejas', 82007),
(82007040, 'Las Rosas', 82007),
(82007050, 'Montes de Oca', 82007),
(82007060, 'Tortugas', 82007),
(82014010, 'Arequito', 82014),
(82014020, 'Arteaga', 82014),
(82014030, 'Beravebú', 82014),
(82014040, 'Bigand', 82014),
(82014050, 'Casilda', 82014),
(82014060, 'Chabas', 82014),
(82014070, 'Chañar Ladeado', 82014),
(82014080, 'Gödeken', 82014),
(82014090, 'Los Molinos', 82014),
(82014100, 'Los Nogales', 82014),
(82014110, 'Los Quirquinchos', 82014),
(82014120, 'San José de la Esquina', 82014),
(82014130, 'Sanford', 82014),
(82014140, 'Villada', 82014),
(82021010, 'Aldao', 82021),
(82021020, 'Angélica', 82021),
(82021030, 'Ataliva', 82021),
(82021040, 'Aurelia', 82021),
(82021050, 'Barrios Acapulco y Veracruz', 82021),
(82021060, 'Bauer y Sigel', 82021),
(82021070, 'Bella Italia', 82021),
(82021080, 'Castellanos', 82021),
(82021090, 'Colonia Bicha', 82021),
(82021100, 'Colonia Cello', 82021),
(82021110, 'Colonia Margarita', 82021),
(82021120, 'Colonia Raquel', 82021),
(82021130, 'Coronel Fraga', 82021),
(82021140, 'Egusquiza', 82021),
(82021150, 'Esmeralda', 82021),
(82021160, 'Estación Clucellas', 82021),
(82021170, 'Estación Saguier', 82021),
(82021180, 'Eusebia y Carolina', 82021),
(82021190, 'Eustolia', 82021),
(82021200, 'Frontera', 82021),
(82021210, 'Garibaldi', 82021),
(82021220, 'Humberto Primo', 82021),
(82021230, 'Josefina', 82021),
(82021240, 'Lehmann', 82021),
(82021250, 'María Juana', 82021),
(82021260, 'Nueva Lehmann', 82021),
(82021270, 'Plaza Clucellas', 82021),
(82021280, 'Plaza Saguier', 82021),
(82021290, 'Presidente Roca', 82021),
(82021300, 'Pueblo Marini', 82021),
(82021310, 'Rafaela', 82021),
(82021320, 'Ramona', 82021),
(82021330, 'San Antonio', 82021),
(82021340, 'San Vicente', 82021),
(82021350, 'Santa Clara de Saguier', 82021),
(82021360, 'Sunchales', 82021),
(82021370, 'Susana', 82021),
(82021380, 'Tacural', 82021),
(82021390, 'Vila', 82021),
(82021400, 'Villa Josefina', 82021),
(82021410, 'Villa San José', 82021),
(82021420, 'Virginia', 82021),
(82021430, 'Zenón Pereyra', 82021),
(82028010, 'Alcorta', 82028),
(82028020, 'Barrio Arroyo del Medio', 82028),
(82028030, 'Barrio Mitre', 82028),
(82028040, 'Bombal', 82028),
(82028050, 'Cañada Rica', 82028),
(82028060, 'Cepeda', 82028),
(82028070, 'Empalme Villa Constitución', 82028),
(82028080, 'Firmat', 82028),
(82028090, 'General Gelly', 82028),
(82028100, 'Godoy', 82028),
(82028110, 'Juan B. Molina', 82028),
(82028120, 'Juncal', 82028),
(82028130, 'La Vanguardia', 82028),
(82028140, 'Máximo Paz', 82028),
(82028150, 'Pavón', 82028),
(82028160, 'Pavón Arriba', 82028),
(82028170, 'Peyrano', 82028),
(82028180, 'Rueda', 82028),
(82028190, 'Santa Teresa', 82028),
(82028200, 'Sargento Cabral', 82028),
(82028210, 'Stephenson', 82028),
(82028220, 'Theobald', 82028),
(82028230, 'Villa Constitución', 82028),
(82035010, 'Cayastá', 82035),
(82035020, 'Helvecia', 82035),
(82035030, 'Los Zapallos', 82035),
(82035040, 'Saladero Mariano Cabal', 82035),
(82035050, 'Santa Rosa de Calchines', 82035),
(82042010, 'Aarón Castellanos', 82042),
(82042020, 'Amenábar', 82042),
(82042030, 'Cafferata', 82042),
(82042040, 'Cañada del Ucle', 82042),
(82042050, 'Carmen', 82042),
(82042060, 'Carreras', 82042),
(82042070, 'Chapuy', 82042),
(82042080, 'Chovet', 82042),
(82042090, 'Christophersen', 82042),
(82042100, 'Diego de Alvear', 82042),
(82042110, 'Elortondo', 82042),
(82042120, 'Firmat', 82042),
(82042130, 'Hughes', 82042),
(82042140, 'La Chispa', 82042),
(82042150, 'Labordeboy', 82042),
(82042160, 'Lazzarino', 82042),
(82042170, 'Maggiolo', 82042),
(82042180, 'María Teresa', 82042),
(82042190, 'Melincué', 82042),
(82042200, 'Miguel Torres', 82042),
(82042210, 'Murphy', 82042),
(82042220, 'Rufino', 82042),
(82042230, 'San Eduardo', 82042),
(82042240, 'San Francisco de Santa Fe', 82042),
(82042250, 'San Gregorio', 82042),
(82042260, 'Sancti Spiritu', 82042),
(82042270, 'Santa Isabel', 82042),
(82042280, 'Teodelina', 82042),
(82042290, 'Venado Tuerto', 82042),
(82042300, 'Villa Cañás', 82042),
(82042310, 'Wheelwright', 82042),
(82049010, 'Arroyo Ceibal', 82049),
(82049020, 'Avellaneda', 82049),
(82049030, 'Berna', 82049),
(82049040, 'El Araza', 82049),
(82049050, 'El Rabón', 82049),
(82049060, 'Florencia', 82049),
(82049070, 'Guadalupe Norte', 82049),
(82049080, 'Ingeniero Chanourdie', 82049),
(82049090, 'La Isleta', 82049),
(82049100, 'La Sarita', 82049),
(82049110, 'Lanteri', 82049),
(82049120, 'Las Garzas', 82049),
(82049130, 'Las Toscas', 82049),
(82049140, 'Los Laureles', 82049),
(82049150, 'Malabrigo', 82049),
(82049160, 'Paraje San Manuel', 82049),
(82049170, 'Puerto Reconquista', 82049),
(82049180, 'Reconquista', 82049),
(82049190, 'San Antonio de Obligado', 82049),
(82049200, 'Tacuarendí', 82049),
(82049210, 'Villa Ana', 82049),
(82049220, 'Villa Guillermina', 82049),
(82049230, 'Villa Ocampo', 82049),
(82056010, 'Barrio Cicarelli', 82056),
(82056020, 'Bustinza', 82056),
(82056030, 'Cañada de Gómez', 82056),
(82056040, 'Carrizales', 82056),
(82056050, 'Classon', 82056),
(82056060, 'Colonia Médici', 82056),
(82056070, 'Correa', 82056),
(82056080, 'Larguía', 82056),
(82056090, 'Lucio V. López', 82056),
(82056100, 'Oliveros', 82056),
(82056110, 'Pueblo Andino', 82056),
(82056120, 'Salto Grande', 82056),
(82056130, 'Serodino', 82056),
(82056140, 'Totoras', 82056),
(82056150, 'Villa Eloísa', 82056),
(82056160, 'Villa La Rivera (Oliveros)', 82056),
(82056170, 'Villa La Rivera (Pueblo Andino)', 82056),
(82063010, 'Angel Gallardo', 82063),
(82063020, 'Arroyo Aguiar', 82063),
(82063030, 'Arroyo Leyes', 82063),
(82063040, 'Cabal', 82063),
(82063050, 'Campo Andino', 82063),
(82063060, 'Candioti', 82063),
(82063070, 'Emilia', 82063),
(82063080, 'Laguna Paiva', 82063),
(82063090, 'Llambi Campbell', 82063),
(82063100, 'Monte Vera', 82063),
(82063110, 'Nelson', 82063),
(82063120, 'Paraje Chaco Chico', 82063),
(82063130, 'Paraje La Costa', 82063),
(82063140, 'Recreo', 82063),
(82063150, 'Rincón Potrero', 82063),
(82063160, 'San José del Rincón', 82063),
(82063170, 'Santa Fe', 82063),
(82063180, 'Santo Tomé', 82063),
(82063190, 'Sauce Viejo', 82063),
(82063200, 'Villa Laura', 82063),
(82070010, 'Cavour', 82070),
(82070020, 'Cululú', 82070),
(82070030, 'Elisa', 82070),
(82070040, 'Empalme San Carlos', 82070),
(82070050, 'Esperanza', 82070),
(82070060, 'Felicia', 82070),
(82070070, 'Franck', 82070),
(82070080, 'Grutly', 82070),
(82070090, 'Hipatía', 82070),
(82070100, 'Humboldt', 82070),
(82070110, 'Jacinto L. Aráuz', 82070),
(82070120, 'La Pelada', 82070),
(82070130, 'Las Tunas', 82070),
(82070140, 'María Luisa', 82070),
(82070150, 'Matilde', 82070),
(82070160, 'Nuevo Torino', 82070),
(82070170, 'Pilar', 82070),
(82070180, 'Plaza Matilde', 82070),
(82070190, 'Progreso', 82070),
(82070200, 'Providencia', 82070),
(82070210, 'Sa Pereyra', 82070),
(82070220, 'San Agustín', 82070),
(82070230, 'San Carlos Centro', 82070),
(82070240, 'San Carlos Norte', 82070),
(82070250, 'San Carlos Sud', 82070),
(82070260, 'San Jerónimo del Sauce', 82070),
(82070270, 'San Jerónimo Norte', 82070),
(82070280, 'San Mariano', 82070),
(82070290, 'Santa Clara de Buena Vista', 82070),
(82070300, 'Santo Domingo', 82070),
(82070310, 'Sarmiento', 82070),
(82077010, 'Esteban Rams', 82077),
(82077020, 'Gato Colorado', 82077),
(82077030, 'Gregoria Pérez de Denis', 82077),
(82077040, 'Logroño', 82077),
(82077050, 'Montefiore', 82077),
(82077060, 'Pozo Borrado', 82077),
(82077065, 'San Bernardo', 82077),
(82077070, 'Santa Margarita', 82077),
(82077080, 'Tostado', 82077),
(82077090, 'Villa Minetti', 82077),
(82084010, 'Acébal', 82084),
(82084020, 'Albarellos', 82084),
(82084030, 'Álvarez', 82084),
(82084040, 'Alvear', 82084),
(82084050, 'Arbilla', 82084),
(82084060, 'Arminda', 82084),
(82084070, 'Arroyo Seco', 82084),
(82084080, 'Carmen del Sauce', 82084),
(82084090, 'Coronel Bogado', 82084),
(82084100, 'Coronel Rodolfo S. Domínguez', 82084),
(82084110, 'Cuatro Esquinas', 82084),
(82084120, 'El Caramelo', 82084),
(82084130, 'Fighiera', 82084),
(82084140, 'Funes', 82084),
(82084150, 'General Lagos', 82084),
(82084160, 'Granadero Baigorria', 82084),
(82084170, 'Ibarlucea', 82084),
(82084180, 'Kilómetro 101', 82084),
(82084190, 'Los Muchachos - La Alborada', 82084),
(82084200, 'Monte Flores', 82084),
(82084210, 'Pérez', 82084),
(82084220, 'Piñero', 82084),
(82084230, 'Pueblo Esther', 82084),
(82084240, 'Pueblo Muñóz', 82084),
(82084250, 'Pueblo Uranga', 82084),
(82084260, 'Puerto Arroyo Seco', 82084),
(82084270, 'Rosario', 82084),
(82084280, 'Soldini', 82084),
(82084290, 'Villa Amelia', 82084),
(82084300, 'Villa del Plata', 82084),
(82084310, 'Villa Gobernador Gálvez', 82084),
(82084320, 'Zavalla', 82084),
(82091010, 'Aguará Grande', 82091),
(82091020, 'Ambrosetti', 82091),
(82091030, 'Arrufo', 82091),
(82091040, 'Balneario La Verde', 82091),
(82091050, 'Capivara', 82091),
(82091060, 'Ceres', 82091),
(82091070, 'Colonia Ana', 82091),
(82091080, 'Colonia Bossi', 82091),
(82091090, 'Colonia Rosa', 82091),
(82091100, 'Constanza', 82091),
(82091110, 'Curupaytí', 82091),
(82091120, 'Hersilia', 82091),
(82091130, 'Huanqueros', 82091),
(82091140, 'La Cabral', 82091),
(82091145, 'La Lucila', 82091),
(82091150, 'La Rubia', 82091),
(82091160, 'Las Avispas', 82091),
(82091170, 'Las Palmeras', 82091),
(82091180, 'Moisés Ville', 82091),
(82091190, 'Monigotes', 82091),
(82091200, 'Ñanducita', 82091),
(82091210, 'Palacios', 82091),
(82091220, 'San Cristóbal', 82091),
(82091230, 'San Guillermo', 82091),
(82091240, 'Santurce', 82091),
(82091250, 'Soledad', 82091),
(82091260, 'Suardi', 82091),
(82091270, 'Villa Saralegui', 82091),
(82091280, 'Villa Trinidad', 82091),
(82098010, 'Alejandra', 82098),
(82098020, 'Cacique Ariacaiquín', 82098),
(82098030, 'Colonia Durán', 82098),
(82098040, 'La Brava', 82098),
(82098050, 'Romang', 82098),
(82098060, 'San Javier', 82098),
(82105010, 'Arocena', 82105),
(82105020, 'Balneario Monje', 82105),
(82105030, 'Barrancas', 82105),
(82105040, 'Barrio Caima', 82105),
(82105050, 'Barrio El Pacaá - Barrio Comipini', 82105),
(82105060, 'Bernardo de Irigoyen', 82105),
(82105070, 'Casalegno', 82105),
(82105080, 'Centeno', 82105),
(82105090, 'Coronda', 82105),
(82105100, 'Desvío Arijón', 82105),
(82105110, 'Díaz', 82105),
(82105120, 'Gaboto', 82105),
(82105130, 'Gálvez', 82105),
(82105140, 'Gessler', 82105),
(82105150, 'Irigoyen', 82105),
(82105160, 'Larrechea', 82105),
(82105170, 'Loma Alta', 82105),
(82105180, 'López', 82105),
(82105190, 'Maciel', 82105),
(82105200, 'Monje', 82105),
(82105210, 'Puerto Aragón', 82105),
(82105220, 'San Eugenio', 82105),
(82105230, 'San Fabián', 82105),
(82105240, 'San Genaro', 82105),
(82105250, 'San Genaro Norte', 82105),
(82112010, 'Angeloni', 82112),
(82112020, 'Cayastacito', 82112),
(82112030, 'Colonia Dolores', 82112),
(82112040, 'Esther', 82112),
(82112050, 'Gobernador Crespo', 82112),
(82112060, 'La Criolla', 82112),
(82112070, 'La Penca y Caraguatá', 82112),
(82112080, 'Marcelino Escalada', 82112),
(82112090, 'Naré', 82112),
(82112100, 'Pedro Gómez Cello', 82112),
(82112110, 'Ramayón', 82112),
(82112120, 'San Bernardo', 82112),
(82112130, 'San Justo', 82112),
(82112140, 'San Martín Norte', 82112),
(82112150, 'Silva', 82112),
(82112160, 'Vera y Pintado', 82112),
(82112170, 'Videla', 82112),
(82119010, 'Aldao', 82119),
(82119020, 'Capitán Bermúdez', 82119),
(82119030, 'Carcarañá', 82119),
(82119040, 'Coronel Arnold', 82119),
(82119050, 'Fray Luis Beltrán', 82119),
(82119060, 'Fuentes', 82119),
(82119070, 'Luis Palacios', 82119),
(82119080, 'Puerto General San Martín', 82119),
(82119090, 'Pujato', 82119),
(82119100, 'Ricardone', 82119),
(82119110, 'Roldán', 82119),
(82119120, 'San Jerónimo Sud', 82119),
(82119130, 'San Lorenzo', 82119),
(82119140, 'Timbúes', 82119),
(82119150, 'Villa Elvira', 82119),
(82119160, 'Villa Mugueta', 82119),
(82126010, 'Cañada Rosquín', 82126),
(82126020, 'Carlos Pellegrini', 82126),
(82126030, 'Casas', 82126),
(82126040, 'Castelar', 82126);
INSERT INTO `localidad` (`id_localidad`, `nombre`, `id_partido`) VALUES
(82126050, 'Colonia Belgrano', 82126),
(82126060, 'Crispi', 82126),
(82126070, 'El Trébol', 82126),
(82126080, 'Landeta', 82126),
(82126090, 'Las Bandurrias', 82126),
(82126100, 'Las Petacas', 82126),
(82126110, 'Los Cardos', 82126),
(82126120, 'María Susana', 82126),
(82126130, 'Piamonte', 82126),
(82126140, 'San Jorge', 82126),
(82126150, 'San Martín de las Escobas', 82126),
(82126160, 'Sastre', 82126),
(82126170, 'Traill', 82126),
(82126180, 'Wildermuth', 82126),
(82133010, 'Calchaquí', 82133),
(82133020, 'Cañada Ombú', 82133),
(82133030, 'Colmena', 82133),
(82133040, 'Fortín Olmos', 82133),
(82133050, 'Garabato', 82133),
(82133060, 'Golondrina', 82133),
(82133070, 'Intiyaco', 82133),
(82133080, 'Kilómetro 115', 82133),
(82133090, 'La Gallareta', 82133),
(82133100, 'Los Amores', 82133),
(82133110, 'Margarita', 82133),
(82133120, 'Paraje 29', 82133),
(82133130, 'Pozo de los Indios', 82133),
(82133140, 'Pueblo Santa Lucía', 82133),
(82133150, 'Tartagal', 82133),
(82133160, 'Toba', 82133),
(82133170, 'Vera', 82133),
(86007010, 'Argentina', 86007),
(86007020, 'Casares', 86007),
(86007030, 'Malbrán', 86007),
(86007040, 'Villa General Mitre', 86007),
(86014010, 'Campo Gallo', 86014),
(86014020, 'Coronel Manuel L. Rico', 86014),
(86014030, 'Donadeu', 86014),
(86014040, 'Sachayoj', 86014),
(86014050, 'Santos Lugares', 86014),
(86021010, 'Estación Atamisqui', 86021),
(86021020, 'Medellín', 86021),
(86021030, 'Villa Atamisqui', 86021),
(86028010, 'Colonia Dora', 86028),
(86028020, 'Herrera', 86028),
(86028030, 'Icaño', 86028),
(86028040, 'Lugones', 86028),
(86028050, 'Real Sayana', 86028),
(86028060, 'Villa Mailín', 86028),
(86035010, 'Abra Grande', 86035),
(86035020, 'Antajé', 86035),
(86035030, 'Ardiles', 86035),
(86035040, 'Cañada Escobar', 86035),
(86035050, 'Chaupi Pozo', 86035),
(86035060, 'Clodomira', 86035),
(86035070, 'Huyamampa', 86035),
(86035080, 'La Aurora', 86035),
(86035090, 'La Banda', 86035),
(86035100, 'La Dársena', 86035),
(86035110, 'Los Quiroga', 86035),
(86035120, 'Los Soria', 86035),
(86035130, 'Simbolar', 86035),
(86035140, 'Tramo 16', 86035),
(86035150, 'Tramo 20', 86035),
(86042010, 'Bandera', 86042),
(86042020, 'Cuatro Bocas', 86042),
(86042030, 'Fortín Inca', 86042),
(86042040, 'Guardia Escolta', 86042),
(86049010, 'El Deán', 86049),
(86049020, 'El Mojón', 86049),
(86049030, 'El Zanjón', 86049),
(86049040, 'Los Cardozos', 86049),
(86049050, 'Maco', 86049),
(86049060, 'Maquito', 86049),
(86049070, 'Morales', 86049),
(86049080, 'Puesto de San Antonio', 86049),
(86049090, 'San Pedro', 86049),
(86049100, 'Santa María', 86049),
(86049110, 'Santiago del Estero', 86049),
(86049120, 'Vuelta de la Barranca', 86049),
(86049130, 'Yanda', 86049),
(86056010, 'El Caburé', 86056),
(86056030, 'Los Pirpintos', 86056),
(86056040, 'Los Tigres', 86056),
(86056050, 'Monte Quemado', 86056),
(86056070, 'Pampa de los Guanacos', 86056),
(86056080, 'San José del Boquerón', 86056),
(86056090, 'Urutaú', 86056),
(86063010, 'Ancaján', 86063),
(86063020, 'Choya', 86063),
(86063030, 'Estación La Punta', 86063),
(86063040, 'Frías', 86063),
(86063050, 'Laprida', 86063),
(86063070, 'San Pedro', 86063),
(86063080, 'Tapso', 86063),
(86063090, 'Villa La Punta', 86063),
(86070010, 'Bandera Bajada', 86070),
(86070020, 'Caspi Corral', 86070),
(86070030, 'Colonia San Juan', 86070),
(86070040, 'El Crucero', 86070),
(86070060, 'La Cañada', 86070),
(86070070, 'La Invernada', 86070),
(86070080, 'Minerva', 86070),
(86070090, 'Vaca Huañuna', 86070),
(86070100, 'Villa Figueroa', 86070),
(86077010, 'Añatuya', 86077),
(86077020, 'Averías', 86077),
(86077030, 'Estación Tacañitas', 86077),
(86077040, 'La Nena', 86077),
(86077050, 'Los Juríes', 86077),
(86077060, 'Tomás Young', 86077),
(86084010, 'Lavalle', 86084),
(86084020, 'San Pedro', 86084),
(86091005, 'El Arenal', 86091),
(86091010, 'El Bobadal', 86091),
(86091020, 'El Charco', 86091),
(86091030, 'El Rincón', 86091),
(86091040, 'Gramilla', 86091),
(86091050, 'Isca Yacu', 86091),
(86091060, 'Isca Yacu Semaul', 86091),
(86091070, 'Pozo Hondo', 86091),
(86091080, 'San Pedro', 86091),
(86098010, 'El Colorado', 86098),
(86098020, 'El Cuadrado', 86098),
(86098030, 'Matará', 86098),
(86098040, 'Suncho Corral', 86098),
(86098050, 'Vilelas', 86098),
(86098060, 'Yuchán', 86098),
(86105010, 'Villa San Martín (Est. Loreto)', 86105),
(86112010, 'Villa Unión', 86112),
(86119010, 'Aerolito', 86119),
(86119020, 'Alhuampa', 86119),
(86119030, 'Hasse', 86119),
(86119040, 'Hernán Mejía Miraval', 86119),
(86119050, 'Las Tinajas', 86119),
(86119060, 'Libertad', 86119),
(86119070, 'Lilo Viejo', 86119),
(86119080, 'Patay', 86119),
(86119090, 'Pueblo Pablo Torelo', 86119),
(86119100, 'Quimili', 86119),
(86119110, 'Roversi', 86119),
(86119120, 'Tintina', 86119),
(86119130, 'Weisburd', 86119),
(86126010, 'El 49', 86126),
(86126020, 'Sol de Julio', 86126),
(86126030, 'Villa Ojo de Agua', 86126),
(86133010, 'El Mojón', 86133),
(86133020, 'Las Delicias', 86133),
(86133030, 'Nueva Esperanza', 86133),
(86133040, 'Pozo Betbeder', 86133),
(86133050, 'Rapelli', 86133),
(86133060, 'Santo Domingo', 86133),
(86140010, 'Ramírez de Velazco', 86140),
(86140020, 'Sumampa', 86140),
(86140030, 'Sumampa Viejo', 86140),
(86147020, 'Chauchillas', 86147),
(86147030, 'Colonia Tinco', 86147),
(86147040, 'El Charco', 86147),
(86147050, 'Gramilla', 86147),
(86147060, 'La Nueva Donosa', 86147),
(86147070, 'Los Miranda', 86147),
(86147080, 'Los Núñez', 86147),
(86147090, 'Mansupa', 86147),
(86147100, 'Pozuelos', 86147),
(86147110, 'Rodeo de Valdez', 86147),
(86147120, 'El Sauzal', 86147),
(86147130, 'Termas de Río Hondo', 86147),
(86147140, 'Villa Giménez', 86147),
(86147150, 'Villa Río Hondo', 86147),
(86147170, 'Vinará', 86147),
(86154010, 'Colonia Alpina', 86154),
(86154020, 'Palo Negro', 86154),
(86154030, 'Selva', 86154),
(86161010, 'Beltrán', 86161),
(86161020, 'Colonia El Simbolar', 86161),
(86161030, 'Fernández', 86161),
(86161040, 'Ingeniero Forres', 86161),
(86161050, 'Vilmer', 86161),
(86168010, 'Chilca Juliana', 86168),
(86168020, 'Los Telares', 86168),
(86168030, 'Villa Salavina', 86168),
(86175010, 'Brea Pozo', 86175),
(86175020, 'Estación Robles', 86175),
(86175030, 'Estación Taboada', 86175),
(86175040, 'Villa Nueva', 86175),
(86182010, 'Garza', 86182),
(86189010, 'Árraga', 86189),
(86189020, 'Nueva Francia', 86189),
(86189030, 'Simbol', 86189),
(86189040, 'Sumamao', 86189),
(86189050, 'Villa Silípica', 86189),
(90007010, 'Barrio San Jorge', 90007),
(90007020, 'El Chañar', 90007),
(90007030, 'El Naranjo', 90007),
(90007040, 'Garmendia', 90007),
(90007050, 'La Ramada', 90007),
(90007060, 'Macomitas', 90007),
(90007070, 'Piedrabuena', 90007),
(90007090, 'Villa Benjamín Aráoz', 90007),
(90007100, 'Villa Burruyacú', 90007),
(90007110, 'Villa Padre Monti', 90007),
(90014010, 'Alderetes', 90014),
(90014020, 'Banda del Río Salí', 90014),
(90014040, 'Colombres', 90014),
(90014050, 'Colonia Mayo - Barrio La Milagrosa', 90014),
(90014060, 'Delfín Gallo', 90014),
(90014070, 'El Bracho', 90014),
(90014080, 'La Florida', 90014),
(90014090, 'Las Cejas', 90014),
(90014100, 'Los Ralos', 90014),
(90014110, 'Pacará', 90014),
(90014120, 'Ranchillos', 90014),
(90014130, 'San Andrés', 90014),
(90021010, 'Alpachiri', 90021),
(90021020, 'Alto Verde', 90021),
(90021030, 'Arcadia', 90021),
(90021050, 'Concepción', 90021),
(90021060, 'Iltico', 90021),
(90021070, 'La Trinidad', 90021),
(90021080, 'Medina', 90021),
(90028020, 'Campo de Herrera', 90028),
(90028030, 'Famaillá', 90028),
(90028040, 'Ingenio Fronterita', 90028),
(90035010, 'Graneros', 90035),
(90035020, 'Lamadrid', 90035),
(90035030, 'Taco Ralo', 90035),
(90042010, 'Juan Bautista Alberdi', 90042),
(90042020, 'Villa Belgrano', 90042),
(90049010, 'La Cocha', 90049),
(90049020, 'San José de La Cocha', 90049),
(90056010, 'Bella Vista', 90056),
(90056020, 'Estación Aráoz', 90056),
(90056030, 'Los Puestos', 90056),
(90056040, 'Manuel García Fernández', 90056),
(90056060, 'Río Colorado', 90056),
(90056070, 'Santa Rosa de Leales', 90056),
(90056080, 'Villa Fiad - Ingenio Leales', 90056),
(90056090, 'Villa de Leales', 90056),
(90063010, 'Barrio San Felipe', 90063),
(90063020, 'El Manantial', 90063),
(90063030, 'Ingenio San Pablo', 90063),
(90063040, 'La Reducción', 90063),
(90063050, 'Lules', 90063),
(90070010, 'Acheral', 90070),
(90070020, 'Capitán Cáceres', 90070),
(90070030, 'Monteros', 90070),
(90070040, 'Pueblo Independencia', 90070),
(90070050, 'Río Seco', 90070),
(90070060, 'Santa Lucía', 90070),
(90070070, 'Sargento Moya', 90070),
(90070080, 'Soldado Maldonado', 90070),
(90070090, 'Teniente Berdina', 90070),
(90070100, 'Villa Quinteros', 90070),
(90077010, 'Aguilares', 90077),
(90077020, 'Los Sarmientos', 90077),
(90077030, 'Río Chico', 90077),
(90077040, 'Santa Ana', 90077),
(90077050, 'Villa Clodomiro Hileret', 90077),
(90084010, 'San Miguel de Tucumán', 90084),
(90091010, 'Atahona', 90091),
(90091020, 'Monteagudo', 90091),
(90091030, 'Nueva Trinidad', 90091),
(90091040, 'Santa Cruz', 90091),
(90091050, 'Simoca', 90091),
(90091060, 'Villa Chicligasta', 90091),
(90098010, 'Amaicha del Valle', 90098),
(90098020, 'Colalao del Valle', 90098),
(90098030, 'El Mollar', 90098),
(90098040, 'Tafí del Valle', 90098),
(90105030, 'Barrio Mutual San Martín', 90105),
(90105070, 'El Cadillal', 90105),
(90105080, 'Tafí Viejo', 90105),
(90105100, 'Villa Mariano Moreno - El Colmenar', 90105),
(90112010, 'Choromoro', 90112),
(90112020, 'San Pedro de Colalao', 90112),
(90112030, 'Villa de Trancas', 90112),
(90119020, 'Villa Carmela', 90119),
(90119030, 'Yerba Buena - Marcos Paz', 90119),
(94008010, 'Río Grande', 94008),
(94015010, 'Laguna Escondida', 94015),
(94015020, 'Ushuaia', 94015),
(94021010, 'Puerto Argentino', 94021),
(200701001, 'Constitución', 2007),
(200701002, 'Monserrat', 2007),
(200701003, 'Puerto Madero', 2007),
(200701004, 'Retiro', 2007),
(200701005, 'San Nicolás', 2007),
(200701006, 'San Telmo', 2007),
(201401001, 'Recoleta', 2014),
(202101001, 'Balvanera', 2021),
(202101002, 'San Cristóbal', 2021),
(202801001, 'Barracas', 2028),
(202801002, 'Boca', 2028),
(202801003, 'Nueva Pompeya', 2028),
(202801004, 'Parque Patricios', 2028),
(203501001, 'Almagro', 2035),
(203501002, 'Boedo', 2035),
(204201001, 'Caballito', 2042),
(204901001, 'Flores', 2049),
(204901002, 'Parque Chacabuco', 2049),
(205601001, 'Villa Lugano', 2056),
(205601002, 'Villa Riachuelo', 2056),
(205601003, 'Villa Soldati', 2056),
(206301001, 'Liniers', 2063),
(206301002, 'Mataderos', 2063),
(206301003, 'Parque Avellaneda', 2063),
(207001001, 'Floresta', 2070),
(207001002, 'Monte Castro', 2070),
(207001003, 'Vélez Sarsfield', 2070),
(207001004, 'Versalles', 2070),
(207001005, 'Villa Luro', 2070),
(207001006, 'Villa Real', 2070),
(207701001, 'Villa del Parque', 2077),
(207701002, 'Villa Devoto', 2077),
(207701003, 'Villa General Mitre', 2077),
(207701004, 'Villa Santa Rita', 2077),
(208401001, 'Coghlan', 2084),
(208401002, 'Saavedra', 2084),
(208401003, 'Villa Pueyrredón', 2084),
(208401004, 'Villa Urquiza', 2084),
(209101001, 'Belgrano', 2091),
(209101002, 'Colegiales', 2091),
(209101003, 'Nuñez', 2091),
(209801001, 'Palermo', 2098),
(210501001, 'Agronomía', 2105),
(210501002, 'Chacarita', 2105),
(210501003, 'Parque Chas', 2105),
(210501004, 'Paternal', 2105),
(210501005, 'Villa Crespo', 2105),
(210501006, 'Villa Ortúzar', 2105),
(602801001, 'Adrogué', 6028),
(602801002, 'Burzaco', 6028),
(602801003, 'Claypole', 6028),
(602801004, 'Don Orione', 6028),
(602801005, 'Glew', 6028),
(602801006, 'José Mármol', 6028),
(602801007, 'Longchamps', 6028),
(602801008, 'Malvinas Argentinas', 6028),
(602801009, 'Ministro Rivadavia', 6028),
(602801010, 'Rafael Calzada', 6028),
(602801011, 'San Francisco Solano', 6028),
(602801012, 'San José', 6028),
(603501001, 'Área Reserva Cinturón Ecológico', 6035),
(603501002, 'Avellaneda', 6035),
(603501003, 'Crucesita', 6035),
(603501004, 'Dock Sud', 6035),
(603501005, 'Gerli', 6035),
(603501006, 'Piñeyro', 6035),
(603501007, 'Sarandí', 6035),
(603501008, 'Villa Domínico', 6035),
(603501009, 'Wilde', 6035),
(605601001, 'Bahía Blanca', 6056),
(605601002, 'Grünbein', 6056),
(605601003, 'Ingeniero White', 6056),
(605601004, 'Villa Bordeau', 6056),
(605601005, 'Villa Espora', 6056),
(609101001, 'Berazategui', 6091),
(609101002, 'Berazategui Oeste', 6091),
(609101003, 'Carlos Tomás Sourigues', 6091),
(609101004, 'El Pato', 6091),
(609101005, 'Guillermo Enrique Hudson', 6091),
(609101006, 'Juan María Gutiérrez', 6091),
(609101007, 'Pereyra', 6091),
(609101008, 'Plátanos', 6091),
(609101009, 'Ranelagh', 6091),
(609101010, 'Villa España', 6091),
(609801001, 'Barrio Banco Provincia', 6098),
(609801002, 'Barrio El Carmen Este', 6098),
(609801003, 'Barrio Universitario', 6098),
(609801004, 'Berisso', 6098),
(609801005, 'Los Talas', 6098),
(609801006, 'Villa Argüello', 6098),
(609801007, 'Villa Dolores', 6098),
(609801008, 'Villa Independencia', 6098),
(609801009, 'Villa Nueva', 6098),
(609801010, 'Villa Porteña', 6098),
(609801011, 'Villa Progreso', 6098),
(609801012, 'Villa San Carlos', 6098),
(609801013, 'Villa Zula', 6098),
(618203001, 'Punta Alta', 6182),
(618203002, 'Villa del Mar', 6182),
(621801001, 'Chascomús', 6218),
(621801003, 'Barrio San Cayetano', 6218),
(624501001, 'Dique N° 1', 6245),
(624501002, 'Ensenada', 6245),
(624501003, 'Isla Santiago', 6245),
(624501004, 'Punta Lara', 6245),
(624501005, 'Villa Catela', 6245),
(625201001, 'Belén de Escobar', 6252),
(625201002, 'El Cazador', 6252),
(625201003, 'Garín', 6252),
(625201004, 'Ingeniero Maschwitz', 6252),
(625201005, 'Loma Verde', 6252),
(625201006, 'Matheu', 6252),
(625201007, 'Maquinista F. Savio Este', 6252),
(626001001, 'Canning', 6260),
(626001002, 'El Jagüel', 6260),
(626001003, 'Luis Guillón', 6260),
(626001004, 'Monte Grande', 6260),
(626001005, '9 de Abril', 6260),
(626606001, 'El Remanso', 6266),
(626606002, 'Parada Robles', 6266),
(626606003, 'Pavón', 6266),
(627001001, 'Aeropuerto Internacional Ezeiza', 6270),
(627001002, 'Canning', 6270),
(627001003, 'Carlos Spegazzini', 6270),
(627001004, 'José María Ezeiza', 6270),
(627001005, 'La Unión', 6270),
(627001006, 'Tristán Suárez', 6270),
(627401001, 'Bosques', 6274),
(627401002, 'Estanislao Severo Zeballos', 6274),
(627401003, 'San Juan Bautista', 6274),
(627401004, 'Gobernador Julio A. Costa', 6274),
(627401005, 'Ingeniero Juan Allan', 6274),
(627401006, 'Villa Brown', 6274),
(627401007, 'Villa San Luis', 6274),
(627401008, 'Villa Santa Rosa', 6274),
(627401009, 'Villa Vatteone', 6274),
(627401010, 'El Tropezón', 6274),
(627401011, 'La Capilla', 6274),
(631501001, 'Barrio Kennedy', 6315),
(631501002, 'General Juan Madariaga', 6315),
(635711001, 'Camet', 6357),
(635711002, 'Estación Camet', 6357),
(635711003, 'Mar del Plata', 6357),
(635711004, 'Punta Mogotes', 6357),
(635711005, 'Barrio El Casal', 6357),
(635712001, 'Barrio Colinas Verdes', 6357),
(635712002, 'Barrio El Coyunco', 6357),
(635712003, 'Barrio La Gloria', 6357),
(635712004, 'Sierra de los Padres', 6357),
(636403001, 'Barrio Morabo', 6364),
(636403002, 'Barrio Ruta 24 Kilómetro 10', 6364),
(636403003, 'Country Club Bosque Real', 6364),
(636403004, 'General Rodríguez', 6364),
(637101001, 'Barrio Parque General San Martín', 6371),
(637101002, 'Billinghurst', 6371),
(637101003, 'Ciudad del Libertador General San Martín', 6371),
(637101004, 'Ciudad Jardín El Libertador', 6371),
(637101005, 'Villa Ayacucho', 6371),
(637101006, 'Villa Ballester', 6371),
(637101007, 'Villa Bernardo Monteagudo', 6371),
(637101008, 'Villa Chacabuco', 6371),
(637101009, 'Villa Coronel José M. Zapiola', 6371),
(637101010, 'Villa General Antonio J. de Sucre', 6371),
(637101011, 'Villa General Eugenio Necochea', 6371),
(637101012, 'Villa General José Tomás Guido', 6371),
(637101013, 'Villa General Juan G. Las Heras', 6371),
(637101014, 'Villa Godoy Cruz', 6371),
(637101015, 'Villa Granaderos de San Martín', 6371),
(637101016, 'Villa Gregoria Matorras', 6371),
(637101017, 'Villa José León Suárez', 6371),
(637101018, 'Villa Juan Martín de Pueyrredón', 6371),
(637101019, 'Villa Libertad', 6371),
(637101020, 'Villa Lynch', 6371),
(637101021, 'Villa Maipú', 6371),
(637101022, 'Va.María Irene de los Remedios Escalada', 6371),
(637101023, 'Va.Marqués Alejandro María de Aguado', 6371),
(637101024, 'Villa Parque Presidente Figueroa Alcorta', 6371),
(637101025, 'Villa Parque San Lorenzo', 6371),
(637101026, 'Villa San Andrés', 6371),
(637101027, 'Villa Yapeyú', 6371),
(640801001, 'Hurlingham', 6408),
(640801002, 'Villa Santos Tesei', 6408),
(640801003, 'William C. Morris', 6408),
(641001001, 'Ituzaingó Centro', 6410),
(641001002, 'Ituzaingó Sur', 6410),
(641001003, 'Villa Gobernador Udadondo', 6410),
(641201001, 'Del Viso', 6412),
(641201002, 'José C. Paz', 6412),
(641201003, 'Tortuguitas', 6412),
(642002001, 'Aguas Verdes', 6420),
(642002002, 'Lucila del Mar', 6420),
(642002003, 'Mar de Ajó', 6420),
(642002004, 'Mar de Ajó Norte', 6420),
(642002005, 'San Bernardo', 6420),
(642004001, 'Mar del Tuyú', 6420),
(642004002, 'Santa Teresita', 6420),
(642701001, 'Aldo Bonzi', 6427),
(642701002, 'Ciudad Evita', 6427),
(642701003, 'González Catán', 6427),
(642701004, 'Gregorio de Laferrere', 6427),
(642701005, 'Isidro Casanova', 6427),
(642701006, 'La Tablada', 6427),
(642701007, 'Lomas del Mirador', 6427),
(642701008, 'Rafael Castillo', 6427),
(642701009, 'Ramos Mejía', 6427),
(642701010, 'San Justo', 6427),
(642701011, 'Tapiales', 6427),
(642701012, '20 de Junio', 6427),
(642701013, 'Villa Eduardo Madero', 6427),
(642701014, 'Villa Luzuriaga', 6427),
(642701015, 'Virrey del Pino', 6427),
(643401001, 'Gerli', 6434),
(643401002, 'Lanús Este', 6434),
(643401003, 'Lanús Oeste', 6434),
(643401004, 'Monte Chingolo', 6434),
(643401005, 'Remedios de Escalada de San Martín', 6434),
(643401006, 'Valentín Alsina', 6434),
(644103001, 'Abasto', 6441),
(644103002, 'Ángel Etcheverry', 6441),
(644103003, 'Arana', 6441),
(644103004, 'Arturo Seguí', 6441),
(644103005, 'Barrio El Carmen Oeste', 6441),
(644103006, 'Barrio Gambier', 6441),
(644103007, 'Barrio Las Malvinas', 6441),
(644103008, 'Barrio Las Quintas', 6441),
(644103009, 'City Bell', 6441),
(644103010, 'El Retiro', 6441),
(644103011, 'Joaquín Gorina', 6441),
(644103012, 'José Hernández', 6441),
(644103013, 'José Melchor Romero', 6441),
(644103014, 'La Cumbre', 6441),
(644103015, 'La Plata', 6441),
(644103016, 'Lisandro Olmos', 6441),
(644103017, 'Los Hornos', 6441),
(644103018, 'Manuel B. Gonnet', 6441),
(644103019, 'Ringuelet', 6441),
(644103020, 'Rufino de Elizalde', 6441),
(644103021, 'Tolosa', 6441),
(644103022, 'Transradio', 6441),
(644103023, 'Villa Elisa', 6441),
(644103024, 'Villa Elvira', 6441),
(644103025, 'Villa Garibaldi', 6441),
(644103026, 'Villa Montoro', 6441),
(644103027, 'Villa Parque Sicardi', 6441),
(649001001, 'Banfield', 6490),
(649001002, 'Llavallol', 6490),
(649001003, 'Lomas de Zamora', 6490),
(649001004, 'Temperley', 6490),
(649001005, 'Turdera', 6490),
(649001006, 'Villa Centenario', 6490),
(649001007, 'Villa Fiorito', 6490),
(649706001, 'Barrio Las Casuarinas', 6497),
(649706002, 'Cortines', 6497),
(649706003, 'Lezica y Torrezuri', 6497),
(649706004, 'Luján', 6497),
(649706005, 'Villa Flandria Norte', 6497),
(649706006, 'Villa Flandria Sur', 6497),
(649706007, 'Country Club Las Praderas', 6497),
(649706008, 'Open Door', 6497),
(651501001, 'Área de Promoción El Triángulo', 6515),
(651501002, 'Grand Bourg', 6515),
(651501003, 'Ingeniero Adolfo Sourdeaux', 6515),
(651501004, 'Ingeniero Pablo Nogués', 6515),
(651501005, 'Los Polvorines', 6515),
(651501006, 'Malvinas Argentinas', 6515),
(651501007, 'Tortuguitas', 6515),
(651501008, 'Villa de Mayo', 6515),
(651805001, 'La Baliza', 6518),
(651805002, 'La Caleta', 6518),
(651805003, 'Mar de Cobo', 6518),
(651806001, 'Atlántida', 6518),
(651806002, 'Camet Norte', 6518),
(651806003, 'Frente Mar', 6518),
(651806004, 'Playa Dorada', 6518),
(651806005, 'Santa Clara del Mar', 6518),
(651806006, 'Santa Elena', 6518),
(652502001, 'Barrio Lisandro de la Torre y Santa Marta', 6525),
(652502002, 'Marcos Paz', 6525),
(653901001, 'Libertad', 6539),
(653901002, 'Mariano Acosta', 6539),
(653901003, 'Merlo', 6539),
(653901004, 'Pontevedra', 6539),
(653901005, 'San Antonio de Padua', 6539),
(656001001, 'Cuartel V', 6560),
(656001002, 'Francisco Álvarez', 6560),
(656001003, 'La Reja', 6560),
(656001004, 'Moreno', 6560),
(656001005, 'Paso del Rey', 6560),
(656001006, 'Trujui', 6560),
(656801001, 'Castelar', 6568),
(656801002, 'El Palomar', 6568),
(656801003, 'Haedo', 6568),
(656801004, 'Morón', 6568),
(656801005, 'Villa Sarmiento', 6568),
(658104001, 'Necochea', 6581),
(658104002, 'Quequén', 6581),
(658104003, 'Costa Bonita', 6581),
(659506001, 'Colonia Hinojo', 6595),
(659506002, 'Hinojo', 6595),
(659511001, 'Sierras Bayas', 6595),
(659511002, 'Villa Arrieta', 6595),
(663804001, 'Del Viso', 6638),
(663804002, 'Fátima', 6638),
(663804003, 'La Lonja', 6638),
(663804004, 'Los Cachorros', 6638),
(663804005, 'Manzanares', 6638),
(663804006, 'Manzone', 6638),
(663804007, 'Maquinista F. Savio Oeste', 6638),
(663804008, 'Pilar', 6638),
(663804009, 'Presidente Derqui', 6638),
(663804010, 'Roberto de Vicenzo', 6638),
(663804011, 'Santa Teresa', 6638),
(663804012, 'Tortuguitas', 6638),
(663804013, 'Villa Astolfi', 6638),
(663804014, 'Villa Rosa', 6638),
(663804015, 'Zelaya', 6638),
(664401001, 'Cariló', 6644),
(664401002, 'Ostende', 6644),
(664401003, 'Pinamar', 6644),
(664401004, 'Valeria del Mar', 6644),
(664801001, 'Barrio América Unida', 6648),
(664801002, 'Guernica', 6648),
(665801001, 'Bernal', 6658),
(665801002, 'Bernal Oeste', 6658),
(665801003, 'Don Bosco', 6658),
(665801004, 'Ezpeleta', 6658),
(665801005, 'Ezpeleta Oeste', 6658),
(665801006, 'Quilmes', 6658),
(665801007, 'Quilmes Oeste', 6658),
(665801008, 'San Francisco Solano', 6658),
(665801009, 'Villa La Florida', 6658),
(668606001, 'Barrio Las Margaritas', 6686),
(668606002, 'Rojas', 6686),
(668606003, 'Villa Parque Cecir', 6686),
(674901001, 'San Fernando', 6749),
(674901002, 'Victoria', 6749),
(674901003, 'Virreyes', 6749),
(675601001, 'Acasusso', 6756),
(675601002, 'Béccar', 6756),
(675601003, 'Boulogne Sur Mer', 6756),
(675601004, 'Martínez', 6756),
(675601005, 'San Isidro', 6756),
(675601006, 'Villa Adelina', 6756),
(676001001, 'Bella Vista', 6760),
(676001002, 'Campo de Mayo', 6760),
(676001003, 'Muñiz', 6760),
(676001004, 'San Miguel', 6760),
(676304001, 'La Emilia', 6763),
(676304002, 'Villa Campi', 6763),
(676304003, 'Villa Canto', 6763),
(676304004, 'Villa Riccio', 6763),
(676305001, 'Campos Salles', 6763),
(676305002, 'San Nicolás de los Arroyos', 6763),
(677802001, 'Alejandro Korn', 6778),
(677802002, 'San Vicente', 6778),
(677802003, 'Domselaar', 6778),
(680501001, 'Benavídez', 6805),
(680501002, 'Dique Luján', 6805),
(680501003, 'Don Torcuato Este', 6805),
(680501004, 'Don Torcuato Oeste', 6805),
(680501005, 'El Talar', 6805),
(680501006, 'General Pacheco', 6805),
(680501007, 'Troncos del Talar', 6805),
(680501008, 'Ricardo Rojas', 6805),
(680501009, 'Rincón de Milberg', 6805),
(680501010, 'Tigre', 6805),
(683302001, 'Claromecó', 6833),
(683302002, 'Dunamar', 6833),
(684001001, 'Caseros', 6840),
(684001002, 'Churruca', 6840),
(684001003, 'Ciudad Jardín Lomas del Palomar', 6840),
(684001004, 'Ciudadela', 6840),
(684001005, 'El Libertador', 6840),
(684001006, 'José Ingenieros', 6840),
(684001007, 'Loma Hermosa', 6840),
(684001008, 'Martín Coronado', 6840),
(684001009, '11 de Septiembre', 6840),
(684001010, 'Pablo Podestá', 6840),
(684001011, 'Remedios de Escalada', 6840),
(684001012, 'Sáenz Peña', 6840),
(684001013, 'Santos Lugares', 6840),
(684001014, 'Villa Bosch', 6840),
(684001015, 'Villa Raffo', 6840),
(686101001, 'Carapachay', 6861),
(686101002, 'Florida', 6861),
(686101003, 'Florida Oeste', 6861),
(686101004, 'La Lucila', 6861),
(686101005, 'Munro', 6861),
(686101006, 'Olivos', 6861),
(686101007, 'Vicente López', 6861),
(686101008, 'Villa Adelina', 6861),
(686101009, 'Villa Martelli', 6861),
(686801001, 'Mar Azul', 6868),
(686801002, 'Mar de las Pampas', 6868),
(688205001, 'Barrio Saavedra', 6882),
(688205002, 'Zárate', 6882),
(1002105001, 'Buena Vista', 10021),
(1002105002, 'El Alamito', 10021),
(1002106001, 'Aconquija', 10021),
(1002106002, 'Alto de las Juntas', 10021),
(1002106003, 'El Lindero', 10021),
(1002106004, 'La Mesada', 10021),
(1004211001, 'Los Ángeles Norte', 10042),
(1004211002, 'Los Ángeles Sur', 10042),
(1006304001, 'El Hueco', 10063),
(1006304002, 'La Carrera', 10063),
(1006304003, 'La Falda de San Antonio', 10063),
(1006304004, 'La Tercena', 10063),
(1006304005, 'San Antonio', 10063),
(1006304006, 'San José', 10063),
(1009103001, 'Chañar Punco', 10091),
(1009103002, 'Lampacito', 10091),
(1009103003, 'Medanitos', 10091),
(1009107001, 'Famatanca', 10091),
(1009107002, 'San José Banda', 10091),
(1009111001, 'El Cerrito', 10091),
(1009111002, 'Las Mojarras', 10091),
(1009114001, 'Casa de Piedra', 10091),
(1009114002, 'La Puntilla', 10091),
(1009114003, 'Palo Seco', 10091),
(1009114004, 'San José Norte', 10091),
(1009114005, 'San José Villa', 10091),
(1010505001, 'Copacabana', 10105),
(1010505002, 'La Puntilla', 10105),
(1010511001, 'Fiambalá', 10105),
(1010511002, 'La Ramadita', 10105),
(1010511003, 'Pampa Blanca', 10105),
(1011204001, 'El Bañado', 10112),
(1011204002, 'Polcos', 10112),
(1011204003, 'Pozo del Mistol', 10112),
(1011204004, 'San Isidro', 10112),
(1011204005, 'Santa Rosa', 10112),
(1011204006, 'Sumalao', 10112),
(1011204007, 'Villa Dolores', 10112),
(1400712001, 'Los Molinos', 14007),
(1400712002, 'Villa San Miguel', 14007),
(1400721001, 'Santa Mónica', 14007),
(1400721002, 'Santa Rosa de Calamuchita', 14007),
(1400721003, 'San Ignacio (Loteo Vélez Crespo)', 14007),
(1400727001, 'Villa Ciudad Parque Los Reartes', 14007),
(1400727002, 'Va.Ciudad Pque.Los Reartes (1° Sección)', 14007),
(1400727003, 'Va.Ciudad Pque.Los Reartes (3° Sección)', 14007),
(1401401001, 'Jardín Arenales', 14014),
(1401401002, 'La Floresta', 14014),
(1401401003, 'Córdoba', 14014),
(1402115001, 'Dumesnil', 14021),
(1402115002, 'La Calera', 14021),
(1402115003, 'El Diquecito', 14021),
(1402125001, 'El Pueblito', 14021),
(1402125002, 'Salsipuedes', 14021),
(1402131001, 'Guiñazú Norte', 14021),
(1402131002, 'Parque Norte', 14021),
(1402131004, '1° de Agosto', 14021),
(1402131005, 'Allmirante Brown', 14021),
(1402131006, 'Ciudad de los Niños', 14021),
(1402131007, 'Villa Pastora', 14021),
(1402132001, 'Juárez Celman', 14021),
(1402132002, 'Villa Los Llanos', 14021),
(1409102001, 'Bialet Massé', 14091),
(1409102002, 'San Roque del Lago', 14091),
(1413319001, 'Alto Resbaloso - El Barrial', 14133),
(1413319002, 'El Pueblito', 14133),
(1413319003, 'El Valle', 14133),
(1413319004, 'Las Chacras', 14133),
(1413319005, 'Villa de las Rosas', 14133),
(1414703001, 'Barrio Gilbert', 14147),
(1414703002, 'Tejas Tres', 14147),
(1414719001, 'Las Quintas', 14147),
(1414719002, 'Los Cedros', 14147),
(1414731001, 'Barrio Villa del Parque', 14147),
(1414731002, 'Villa Ciudad de América', 14147),
(1414732001, 'Villa del Prado', 14147),
(1414732002, 'La Donosa', 14147),
(1414735001, 'Mi Valle', 14147),
(1414735002, 'Villa Parque Santa Ana', 14147),
(2147483647, 'Recaredo', 66056);

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

--
-- Volcado de datos para la tabla `partido`
--

INSERT INTO `partido` (`id_partido`, `nombre`, `id_provincia`) VALUES
(2007, 'Comuna 1', 2),
(2014, 'Comuna 2', 2),
(2021, 'Comuna 3', 2),
(2028, 'Comuna 4', 2),
(2035, 'Comuna 5', 2),
(2042, 'Comuna 6', 2),
(2049, 'Comuna 7', 2),
(2056, 'Comuna 8', 2),
(2063, 'Comuna 9', 2),
(2070, 'Comuna 10', 2),
(2077, 'Comuna 11', 2),
(2084, 'Comuna 12', 2),
(2091, 'Comuna 13', 2),
(2098, 'Comuna 14', 2),
(2105, 'Comuna 15', 2),
(6007, 'Adolfo Alsina', 6),
(6014, 'Adolfo Gonzales Chaves', 6),
(6021, 'Alberti', 6),
(6028, 'Almirante Brown', 6),
(6035, 'Avellaneda', 6),
(6042, 'Ayacucho', 6),
(6049, 'Azul', 6),
(6056, 'Bahía Blanca', 6),
(6063, 'Balcarce', 6),
(6070, 'Baradero', 6),
(6077, 'Arrecifes', 6),
(6084, 'Benito Juárez', 6),
(6091, 'Berazategui', 6),
(6098, 'Berisso', 6),
(6105, 'Bolívar', 6),
(6112, 'Bragado', 6),
(6119, 'Brandsen', 6),
(6126, 'Campana', 6),
(6134, 'Cañuelas', 6),
(6140, 'Capitán Sarmiento', 6),
(6147, 'Carlos Casares', 6),
(6154, 'Carlos Tejedor', 6),
(6161, 'Carmen de Areco', 6),
(6168, 'Castelli', 6),
(6175, 'Colón', 6),
(6182, 'Coronel de Marina Leonardo Rosales', 6),
(6189, 'Coronel Dorrego', 6),
(6196, 'Coronel Pringles', 6),
(6203, 'Coronel Suárez', 6),
(6210, 'Chacabuco', 6),
(6218, 'Chascomús', 6),
(6224, 'Chivilcoy', 6),
(6231, 'Daireaux', 6),
(6238, 'Dolores', 6),
(6245, 'Ensenada', 6),
(6252, 'Escobar', 6),
(6260, 'Esteban Echeverría', 6),
(6266, 'Exaltación de la Cruz', 6),
(6270, 'Ezeiza', 6),
(6274, 'Florencio Varela', 6),
(6277, 'Florentino Ameghino', 6),
(6280, 'General Alvarado', 6),
(6287, 'General Alvear', 6),
(6294, 'General Arenales', 6),
(6301, 'General Belgrano', 6),
(6308, 'General Guido', 6),
(6315, 'General Juan Madariaga', 6),
(6322, 'General La Madrid', 6),
(6329, 'General Las Heras', 6),
(6336, 'General Lavalle', 6),
(6343, 'General Paz', 6),
(6351, 'General Pinto', 6),
(6357, 'General Pueyrredón', 6),
(6364, 'General Rodríguez', 6),
(6371, 'General San Martín', 6),
(6385, 'General Viamonte', 6),
(6392, 'General Villegas', 6),
(6399, 'Guaminí', 6),
(6406, 'Hipólito Yrigoyen', 6),
(6408, 'Hurlingham', 6),
(6410, 'Ituzaingó', 6),
(6412, 'José C. Paz', 6),
(6413, 'Junín', 6),
(6420, 'La Costa', 6),
(6427, 'La Matanza', 6),
(6434, 'Lanús', 6),
(6441, 'La Plata', 6),
(6448, 'Laprida', 6),
(6455, 'Las Flores', 6),
(6462, 'Leandro N. Alem', 6),
(6466, 'Lezama', 6),
(6469, 'Lincoln', 6),
(6476, 'Lobería', 6),
(6483, 'Lobos', 6),
(6490, 'Lomas de Zamora', 6),
(6497, 'Luján', 6),
(6505, 'Magdalena', 6),
(6511, 'Maipú', 6),
(6515, 'Malvinas Argentinas', 6),
(6518, 'Mar Chiquita', 6),
(6525, 'Marcos Paz', 6),
(6532, 'Mercedes', 6),
(6539, 'Merlo', 6),
(6547, 'Monte', 6),
(6553, 'Monte Hermoso', 6),
(6560, 'Moreno', 6),
(6568, 'Morón', 6),
(6574, 'Navarro', 6),
(6581, 'Necochea', 6),
(6588, '9 de Julio', 6),
(6595, 'Olavarría', 6),
(6602, 'Patagones', 6),
(6609, 'Pehuajó', 6),
(6616, 'Pellegrini', 6),
(6623, 'Pergamino', 6),
(6630, 'Pila', 6),
(6638, 'Pilar', 6),
(6644, 'Pinamar', 6),
(6648, 'Presidente Perón', 6),
(6651, 'Puán', 6),
(6655, 'Punta Indio', 6),
(6658, 'Quilmes', 6),
(6665, 'Ramallo', 6),
(6672, 'Rauch', 6),
(6679, 'Rivadavia', 6),
(6686, 'Rojas', 6),
(6693, 'Roque Pérez', 6),
(6700, 'Saavedra', 6),
(6707, 'Saladillo', 6),
(6714, 'Salto', 6),
(6721, 'Salliqueló', 6),
(6728, 'San Andrés de Giles', 6),
(6735, 'San Antonio de Areco', 6),
(6742, 'San Cayetano', 6),
(6749, 'San Fernando', 6),
(6756, 'San Isidro', 6),
(6760, 'San Miguel', 6),
(6763, 'San Nicolás', 6),
(6770, 'San Pedro', 6),
(6778, 'San Vicente', 6),
(6784, 'Suipacha', 6),
(6791, 'Tandil', 6),
(6798, 'Tapalqué', 6),
(6805, 'Tigre', 6),
(6812, 'Tordillo', 6),
(6819, 'Tornquist', 6),
(6826, 'Trenque Lauquen', 6),
(6833, 'Tres Arroyos', 6),
(6840, 'Tres de Febrero', 6),
(6847, 'Tres Lomas', 6),
(6854, '25 de Mayo', 6),
(6861, 'Vicente López', 6),
(6868, 'Villa Gesell', 6),
(6875, 'Villarino', 6),
(6882, 'Zárate', 6),
(10007, 'Ambato', 10),
(10014, 'Ancasti', 10),
(10021, 'Andalgalá', 10),
(10028, 'Antofagasta de la Sierra', 10),
(10035, 'Belén', 10),
(10042, 'Capayán', 10),
(10049, 'Capital', 10),
(10056, 'El Alto', 10),
(10063, 'Fray Mamerto Esquiú', 10),
(10070, 'La Paz', 10),
(10077, 'Paclín', 10),
(10084, 'Pomán', 10),
(10091, 'Santa María', 10),
(10098, 'Santa Rosa', 10),
(10105, 'Tinogasta', 10),
(10112, 'Valle Viejo', 10),
(14007, 'Calamuchita', 14),
(14014, 'Capital', 14),
(14021, 'Colón', 14),
(14028, 'Cruz del Eje', 14),
(14035, 'General Roca', 14),
(14042, 'General San Martín', 14),
(14049, 'Ischilín', 14),
(14056, 'Juárez Celman', 14),
(14063, 'Marcos Juárez', 14),
(14070, 'Minas', 14),
(14077, 'Pocho', 14),
(14084, 'Presidente Roque Sáenz Peña', 14),
(14091, 'Punilla', 14),
(14098, 'Río Cuarto', 14),
(14105, 'Río Primero', 14),
(14112, 'Río Seco', 14),
(14119, 'Río Segundo', 14),
(14126, 'San Alberto', 14),
(14133, 'San Javier', 14),
(14140, 'San Justo', 14),
(14147, 'Santa María', 14),
(14154, 'Sobremonte', 14),
(14161, 'Tercero Arriba', 14),
(14168, 'Totoral', 14),
(14175, 'Tulumba', 14),
(14182, 'Unión', 14),
(18007, 'Bella Vista', 18),
(18014, 'Berón de Astrada', 18),
(18021, 'Capital', 18),
(18028, 'Concepción', 18),
(18035, 'Curuzú Cuatiá', 18),
(18042, 'Empedrado', 18),
(18049, 'Esquina', 18),
(18056, 'General Alvear', 18),
(18063, 'General Paz', 18),
(18070, 'Goya', 18),
(18077, 'Itatí', 18),
(18084, 'Ituzaingó', 18),
(18091, 'Lavalle', 18),
(18098, 'Mburucuyá', 18),
(18105, 'Mercedes', 18),
(18112, 'Monte Caseros', 18),
(18119, 'Paso de los Libres', 18),
(18126, 'Saladas', 18),
(18133, 'San Cosme', 18),
(18140, 'San Luis del Palmar', 18),
(18147, 'San Martín', 18),
(18154, 'San Miguel', 18),
(18161, 'San Roque', 18),
(18168, 'Santo Tomé', 18),
(18175, 'Sauce', 18),
(22007, 'Almirante Brown', 22),
(22014, 'Bermejo', 22),
(22021, 'Comandante Fernández', 22),
(22028, 'Chacabuco', 22),
(22036, '12 de Octubre', 22),
(22039, '2 de Abril', 22),
(22043, 'Fray Justo Santa María de Oro', 22),
(22049, 'General Belgrano', 22),
(22056, 'General Donovan', 22),
(22063, 'General Güemes', 22),
(22070, 'Independencia', 22),
(22077, 'Libertad', 22),
(22084, 'Libertador General San Martín', 22),
(22091, 'Maipú', 22),
(22098, 'Mayor Luis J. Fontana', 22),
(22105, '9 de Julio', 22),
(22112, 'O\'Higgins', 22),
(22119, 'Presidencia de la Plaza', 22),
(22126, '1° de Mayo', 22),
(22133, 'Quitilipi', 22),
(22140, 'San Fernando', 22),
(22147, 'San Lorenzo', 22),
(22154, 'Sargento Cabral', 22),
(22161, 'Tapenagá', 22),
(22168, '25 de Mayo', 22),
(26007, 'Biedma', 26),
(26014, 'Cushamen', 26),
(26021, 'Escalante', 26),
(26028, 'Florentino Ameghino', 26),
(26035, 'Futaleufú', 26),
(26042, 'Gaiman', 26),
(26049, 'Gastre', 26),
(26056, 'Languiñeo', 26),
(26063, 'Mártires', 26),
(26070, 'Paso de Indios', 26),
(26077, 'Rawson', 26),
(26084, 'Río Senguer', 26),
(26091, 'Sarmiento', 26),
(26098, 'Tehuelches', 26),
(26105, 'Telsen', 26),
(30008, 'Colón', 30),
(30015, 'Concordia', 30),
(30021, 'Diamante', 30),
(30028, 'Federación', 30),
(30035, 'Federal', 30),
(30042, 'Feliciano', 30),
(30049, 'Gualeguay', 30),
(30056, 'Gualeguaychú', 30),
(30063, 'Islas del Ibicuy', 30),
(30070, 'La Paz', 30),
(30077, 'Nogoyá', 30),
(30084, 'Paraná', 30),
(30088, 'San Salvador', 30),
(30091, 'Tala', 30),
(30098, 'Uruguay', 30),
(30105, 'Victoria', 30),
(30113, 'Villaguay', 30),
(34007, 'Bermejo', 34),
(34014, 'Formosa', 34),
(34021, 'Laishi', 34),
(34028, 'Matacos', 34),
(34035, 'Patiño', 34),
(34042, 'Pilagás', 34),
(34049, 'Pilcomayo', 34),
(34056, 'Pirané', 34),
(34063, 'Ramón Lista', 34),
(38007, 'Cochinoca', 38),
(38014, 'El Carmen', 38),
(38021, 'Dr. Manuel Belgrano', 38),
(38028, 'Humahuaca', 38),
(38035, 'Ledesma', 38),
(38042, 'Palpalá', 38),
(38049, 'Rinconada', 38),
(38056, 'San Antonio', 38),
(38063, 'San Pedro', 38),
(38070, 'Santa Bárbara', 38),
(38077, 'Santa Catalina', 38),
(38084, 'Susques', 38),
(38094, 'Tilcara', 38),
(38098, 'Tumbaya', 38),
(38105, 'Valle Grande', 38),
(38112, 'Yavi', 38),
(42007, 'Atreucó', 42),
(42014, 'Caleu Caleu', 42),
(42021, 'Capital', 42),
(42028, 'Catriló', 42),
(42035, 'Conhelo', 42),
(42042, 'Curacó', 42),
(42049, 'Chalileo', 42),
(42056, 'Chapaleufú', 42),
(42063, 'Chical Co', 42),
(42070, 'Guatraché', 42),
(42077, 'Hucal', 42),
(42084, 'Lihuel Calel', 42),
(42091, 'Limay Mahuida', 42),
(42098, 'Loventué', 42),
(42105, 'Maracó', 42),
(42112, 'Puelén', 42),
(42119, 'Quemú Quemú', 42),
(42126, 'Rancul', 42),
(42133, 'Realicó', 42),
(42140, 'Toay', 42),
(42147, 'Trenel', 42),
(42154, 'Utracán', 42),
(46007, 'Arauco', 46),
(46014, 'Capital', 46),
(46021, 'Castro Barros', 46),
(46028, 'General Felipe Varela', 46),
(46035, 'Chamical', 46),
(46042, 'Chilecito', 46),
(46049, 'Famatina', 46),
(46056, 'Ángel Vicente Peñaloza', 46),
(46063, 'General Belgrano', 46),
(46070, 'General Juan Facundo Quiroga', 46),
(46077, 'General Lamadrid', 46),
(46084, 'General Ortiz de Ocampo', 46),
(46091, 'General San Martín', 46),
(46098, 'Vinchina', 46),
(46105, 'Independencia', 46),
(46112, 'Rosario Vera Peñaloza', 46),
(46119, 'San Blas de Los Sauces', 46),
(46126, 'Sanagasta', 46),
(50007, 'Capital', 50),
(50014, 'General Alvear', 50),
(50021, 'Godoy Cruz', 50),
(50028, 'Guaymallén', 50),
(50035, 'Junín', 50),
(50042, 'La Paz', 50),
(50049, 'Las Heras', 50),
(50056, 'Lavalle', 50),
(50063, 'Luján de Cuyo', 50),
(50070, 'Maipú', 50),
(50077, 'Malargüe', 50),
(50084, 'Rivadavia', 50),
(50091, 'San Carlos', 50),
(50098, 'San Martín', 50),
(50105, 'San Rafael', 50),
(50112, 'Santa Rosa', 50),
(50119, 'Tunuyán', 50),
(50126, 'Tupungato', 50),
(54007, 'Apóstoles', 54),
(54014, 'Cainguás', 54),
(54021, 'Candelaria', 54),
(54028, 'Capital', 54),
(54035, 'Concepción', 54),
(54042, 'Eldorado', 54),
(54049, 'General Manuel Belgrano', 54),
(54056, 'Guaraní', 54),
(54063, 'Iguazú', 54),
(54070, 'Leandro N. Alem', 54),
(54077, 'Libertador General San Martín', 54),
(54084, 'Montecarlo', 54),
(54091, 'Oberá', 54),
(54098, 'San Ignacio', 54),
(54105, 'San Javier', 54),
(54112, 'San Pedro', 54),
(54119, '25 de Mayo', 54),
(58007, 'Aluminé', 58),
(58014, 'Añelo', 58),
(58021, 'Catán Lil', 58),
(58028, 'Collón Curá', 58),
(58035, 'Confluencia', 58),
(58042, 'Chos Malal', 58),
(58049, 'Huiliches', 58),
(58056, 'Lácar', 58),
(58063, 'Loncopué', 58),
(58070, 'Los Lagos', 58),
(58077, 'Minas', 58),
(58084, 'Ñorquín', 58),
(58091, 'Pehuenches', 58),
(58098, 'Picún Leufú', 58),
(58105, 'Picunches', 58),
(58112, 'Zapala', 58),
(62007, 'Adolfo Alsina', 62),
(62014, 'Avellaneda', 62),
(62021, 'Bariloche', 62),
(62028, 'Conesa', 62),
(62035, 'El Cuy', 62),
(62042, 'General Roca', 62),
(62049, '9 de Julio', 62),
(62056, 'Ñorquinco', 62),
(62063, 'Pichi Mahuida', 62),
(62070, 'Pilcaniyeu', 62),
(62077, 'San Antonio', 62),
(62084, 'Valcheta', 62),
(62091, '25 de Mayo', 62),
(66007, 'Anta', 66),
(66014, 'Cachi', 66),
(66021, 'Cafayate', 66),
(66028, 'Capital', 66),
(66035, 'Cerrillos', 66),
(66042, 'Chicoana', 66),
(66049, 'General Güemes', 66),
(66056, 'General José de San Martín', 66),
(66063, 'Guachipas', 66),
(66070, 'Iruya', 66),
(66077, 'La Caldera', 66),
(66084, 'La Candelaria', 66),
(66091, 'La Poma', 66),
(66098, 'La Viña', 66),
(66105, 'Los Andes', 66),
(66112, 'Metán', 66),
(66119, 'Molinos', 66),
(66126, 'Orán', 66),
(66133, 'Rivadavia', 66),
(66140, 'Rosario de la Frontera', 66),
(66147, 'Rosario de Lerma', 66),
(66154, 'San Carlos', 66),
(66161, 'Santa Victoria', 66),
(70007, 'Albardón', 70),
(70014, 'Angaco', 70),
(70021, 'Calingasta', 70),
(70028, 'Capital', 70),
(70035, 'Caucete', 70),
(70042, 'Chimbas', 70),
(70049, 'Iglesia', 70),
(70056, 'Jáchal', 70),
(70063, '9 de Julio', 70),
(70070, 'Pocito', 70),
(70077, 'Rawson', 70),
(70084, 'Rivadavia', 70),
(70091, 'San Martín', 70),
(70098, 'Santa Lucía', 70),
(70105, 'Sarmiento', 70),
(70112, 'Ullum', 70),
(70119, 'Valle Fértil', 70),
(70126, '25 de Mayo', 70),
(70133, 'Zonda', 70),
(74007, 'Ayacucho', 74),
(74014, 'Belgrano', 74),
(74021, 'Coronel Pringles', 74),
(74028, 'Chacabuco', 74),
(74035, 'General Pedernera', 74),
(74042, 'Gobernador Dupuy', 74),
(74049, 'Junín', 74),
(74056, 'Juan Martín de Pueyrredón', 74),
(74063, 'Libertador General San Martín', 74),
(78007, 'Corpen Aike', 78),
(78014, 'Deseado', 78),
(78021, 'Güer Aike', 78),
(78028, 'Lago Argentino', 78),
(78035, 'Lago Buenos Aires', 78),
(78042, 'Magallanes', 78),
(78049, 'Río Chico', 78),
(82007, 'Belgrano', 82),
(82014, 'Caseros', 82),
(82021, 'Castellanos', 82),
(82028, 'Constitución', 82),
(82035, 'Garay', 82),
(82042, 'General López', 82),
(82049, 'General Obligado', 82),
(82056, 'Iriondo', 82),
(82063, 'La Capital', 82),
(82070, 'Las Colonias', 82),
(82077, '9 de Julio', 82),
(82084, 'Rosario', 82),
(82091, 'San Cristóbal', 82),
(82098, 'San Javier', 82),
(82105, 'San Jerónimo', 82),
(82112, 'San Justo', 82),
(82119, 'San Lorenzo', 82),
(82126, 'San Martín', 82),
(82133, 'Vera', 82),
(86007, 'Aguirre', 86),
(86014, 'Alberdi', 86),
(86021, 'Atamisqui', 86),
(86028, 'Avellaneda', 86),
(86035, 'Banda', 86),
(86042, 'Belgrano', 86),
(86049, 'Capital', 86),
(86056, 'Copo', 86),
(86063, 'Choya', 86),
(86070, 'Figueroa', 86),
(86077, 'General Taboada', 86),
(86084, 'Guasayán', 86),
(86091, 'Jiménez', 86),
(86098, 'Juan Felipe Ibarra', 86),
(86105, 'Loreto', 86),
(86112, 'Mitre', 86),
(86119, 'Moreno', 86),
(86126, 'Ojo de Agua', 86),
(86133, 'Pellegrini', 86),
(86140, 'Quebrachos', 86),
(86147, 'Río Hondo', 86),
(86154, 'Rivadavia', 86),
(86161, 'Robles', 86),
(86168, 'Salavina', 86),
(86175, 'San Martín', 86),
(86182, 'Sarmiento', 86),
(86189, 'Silípica', 86),
(90007, 'Burruyacú', 90),
(90014, 'Cruz Alta', 90),
(90021, 'Chicligasta', 90),
(90028, 'Famaillá', 90),
(90035, 'Graneros', 90),
(90042, 'Juan Bautista Alberdi', 90),
(90049, 'La Cocha', 90),
(90056, 'Leales', 90),
(90063, 'Lules', 90),
(90070, 'Monteros', 90),
(90077, 'Río Chico', 90),
(90084, 'Capital', 90),
(90091, 'Simoca', 90),
(90098, 'Tafí del Valle', 90),
(90105, 'Tafí Viejo', 90),
(90112, 'Trancas', 90),
(90119, 'Yerba Buena', 90),
(94008, 'Río Grande', 94),
(94011, 'Tolhuin', 94),
(94015, 'Ushuaia', 94),
(94021, 'Islas del Atlántico Sur', 94),
(94028, 'Antártida Argentina', 94);

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
(13, 39, 1, NULL, 266000.00, '2025-06-26 05:25:08', 'Lautaro', 'asdasdasd', '23232323'),
(14, 47, 1, NULL, 216000.00, '2025-06-29 22:35:05', 'Lautaro', 'Souza', '47941303');

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

--
-- Volcado de datos para la tabla `provincia`
--

INSERT INTO `provincia` (`id_provincia`, `nombre`) VALUES
(6, 'Buenos Aires'),
(10, 'Catamarca'),
(22, 'Chaco'),
(26, 'Chubut'),
(2, 'Ciudad Autónoma de Buenos Aires'),
(14, 'Córdoba'),
(18, 'Corrientes'),
(30, 'Entre Ríos'),
(34, 'Formosa'),
(38, 'Jujuy'),
(42, 'La Pampa'),
(46, 'La Rioja'),
(50, 'Mendoza'),
(54, 'Misiones'),
(58, 'Neuquén'),
(62, 'Río Negro'),
(66, 'Salta'),
(70, 'San Juan'),
(74, 'San Luis'),
(78, 'Santa Cruz'),
(82, 'Santa Fe'),
(86, 'Santiago del Estero'),
(94, 'Tierra del Fuego, Antártida e Islas del Atlántico Sur'),
(90, 'Tucumán');

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
-- Estructura de tabla para la tabla `roles`
--

CREATE TABLE `roles` (
  `id_rol` int(11) NOT NULL,
  `nombre_rol` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `roles`
--

INSERT INTO `roles` (`id_rol`, `nombre_rol`) VALUES
(1, 'admin'),
(2, 'usuario');

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
  `id_dato` int(11) DEFAULT NULL,
  `id_verify` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `usuario_nombre`, `email`, `contraseña`, `id_rol`, `id_dato`, `id_verify`) VALUES
(39, 'Hooooooz', 'blablabla@gmail.com', '$2y$10$0wBks12fU4fyLhs7Xc.8NuDZ/Uxa9cM9OzWCRVB6ZMLH3VT6WTqGW', NULL, NULL, NULL),
(40, 'Hola', 'lautarobenjaminsouza@gmail.com', '$2y$10$icZPr7PAXihKx2Y7cd.4deTY.QG0lZT1o055Q4wfR46VZQBpBYt.C', NULL, NULL, NULL),
(41, 'dsadsadsad', 'lautarobenjaminsouz23232a@gmail.com', '$2y$10$x0fzivN4VhblfFRfwFzgWexfD89gmpW0Vyp7EU6K17.Xa7XB.QJye', NULL, NULL, NULL),
(42, 'Hoooooozhgyt', 'cuentag54r5644x@gmail.com', '$2y$10$QwuM8xYRsC/YYmBU9k7HFuQdLPXXZznpnO79abz2n1sCbM1/TMW5q', NULL, NULL, NULL),
(43, 'Hoooooozhgyt', 'safarakir232155135i@gmail.com', '$2y$10$G4EXISm/qTYl1tjY65yYTeHM1OyaciDh6SxlT7CNHPiegVH7s9rVm', NULL, NULL, NULL),
(44, 'blabla2', 'mamacenso@gmail.com', '$2y$10$RBXWHtoRikz6CVdwvImxgugPmsjDuZprMIwpoVNPVShLdhPt2Xwzm', NULL, NULL, NULL),
(47, 'Admin', 'lautarosouza58@gmail.com', '$2y$10$JRDmbK1KDFhuqHrOXwP7ueAzDETrJNOmy05oW0R4dXiNf2ifn/2JK', 1, NULL, 2),
(49, 'Admin', 'zetazetazeta@gmail.com', '$2y$10$elUJ3lU5YEZ8W4pG6gBA3upB3cv5uF0VGM/WnnXmnaIt9n42M/skC', 2, NULL, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `verify_email`
--

CREATE TABLE `verify_email` (
  `id_verify` int(11) NOT NULL,
  `verificado` varchar(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `verify_email`
--

INSERT INTO `verify_email` (`id_verify`, `verificado`) VALUES
(1, 'si'),
(2, 'no');

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
  ADD KEY `fk_admin_usuario` (`id_usuario`);

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
  ADD KEY `fk_datos_localidad` (`id_localidad`);

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
  ADD KEY `fk_localidad_partido` (`id_partido`);

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
  ADD KEY `fk_partido_provincia` (`id_provincia`);

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
  ADD PRIMARY KEY (`id_provincia`),
  ADD UNIQUE KEY `nombre` (`nombre`);

--
-- Indices de la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD PRIMARY KEY (`id_reserva`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_paquete` (`id_paquete`);

--
-- Indices de la tabla `roles`
--
ALTER TABLE `roles`
  ADD PRIMARY KEY (`id_rol`);

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
  ADD KEY `fk_datos_personales` (`id_dato`),
  ADD KEY `fk_roles` (`id_rol`) USING BTREE,
  ADD KEY `fk_usuarios_verify` (`id_verify`);

--
-- Indices de la tabla `verify_email`
--
ALTER TABLE `verify_email`
  ADD PRIMARY KEY (`id_verify`);

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
  MODIFY `id_carrito` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT de la tabla `carrito_items`
--
ALTER TABLE `carrito_items`
  MODIFY `id_item` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=37;

--
-- AUTO_INCREMENT de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  MODIFY `id_dato` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

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
  MODIFY `id_detallepedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=29;

--
-- AUTO_INCREMENT de la tabla `email_resets`
--
ALTER TABLE `email_resets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

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
  MODIFY `id_localidad` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2147483648;

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
  MODIFY `id_partido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=94029;

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
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=42;

--
-- AUTO_INCREMENT de la tabla `provincia`
--
ALTER TABLE `provincia`
  MODIFY `id_provincia` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=95;

--
-- AUTO_INCREMENT de la tabla `reservas`
--
ALTER TABLE `reservas`
  MODIFY `id_reserva` int(11) NOT NULL AUTO_INCREMENT;

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
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT de la tabla `verify_email`
--
ALTER TABLE `verify_email`
  MODIFY `id_verify` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `acciones_admins`
--
ALTER TABLE `acciones_admins`
  ADD CONSTRAINT `acciones_admins_ibfk_1` FOREIGN KEY (`id_admin`) REFERENCES `admins` (`id_admin`);

--
-- Filtros para la tabla `admins`
--
ALTER TABLE `admins`
  ADD CONSTRAINT `fk_admin_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`);

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
  ADD CONSTRAINT `fk_datos_localidad` FOREIGN KEY (`id_localidad`) REFERENCES `localidad` (`id_localidad`);

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
  ADD CONSTRAINT `fk_localidad_partido` FOREIGN KEY (`id_partido`) REFERENCES `partido` (`id_partido`);

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
  ADD CONSTRAINT `fk_partido_provincia` FOREIGN KEY (`id_provincia`) REFERENCES `provincia` (`id_provincia`);

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
  ADD CONSTRAINT `fk_usuarios_roles` FOREIGN KEY (`id_rol`) REFERENCES `roles` (`id_rol`),
  ADD CONSTRAINT `fk_usuarios_verify` FOREIGN KEY (`id_verify`) REFERENCES `verify_email` (`id_verify`) ON DELETE SET NULL ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
