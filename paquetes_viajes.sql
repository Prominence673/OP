-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 23-06-2025 a las 02:36:11
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPBringPassword` (IN `p_email` VARCHAR(60))   BEGIN
 SELECT contraseña FROM usuarios WHERE email = p_email;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPbrinUser` (IN `P_Email` VARCHAR(64))   BEGIN 
SELECT id_usuario , usuario_nombre FROM usuarios WHERE email = P_Email;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPChangePassword` (IN `p_email` VARCHAR(64), IN `p_hash_password` VARCHAR(255))   BEGIN
    UPDATE usuarios
    SET contraseña = p_hash_password
    WHERE email = p_email
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPGetPasswordResetByToken` (IN `p_token` VARCHAR(64))   BEGIN
    SELECT id_usuario, expires_at
    FROM password_resets
    WHERE token = p_token;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPInsertarDatosPersonales` (IN `p_id_usuario` INT, IN `p_nombre` VARCHAR(50), IN `p_apellido` VARCHAR(50), IN `p_fecha_nacimiento` DATE, IN `p_genero` VARCHAR(20), IN `p_id_pasajero` INT, IN `p_imagen_ruta` TEXT)   BEGIN
  DECLARE existe INT;

  SELECT COUNT(*) INTO existe FROM datos_personales WHERE id_usuario = p_id_usuario;

  IF existe > 0 THEN
    -- Actualiza si ya existe
    UPDATE datos_personales
    SET nombre = p_nombre,
        apellido = p_apellido,
        fecha_nacimiento = p_fecha_nacimiento,
        genero = p_genero,
        id_pasajero = p_id_pasajero,
        imagen_ruta = p_imagen_ruta
    WHERE id_usuario = p_id_usuario;
  ELSE
    -- Inserta si no existe
    INSERT INTO datos_personales (id_usuario, nombre, apellido, fecha_nacimiento, genero, id_pasajero, imagen_ruta)
    VALUES (p_id_usuario, p_nombre, p_apellido, p_fecha_nacimiento, p_genero, p_id_pasajero, p_imagen_ruta);
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPInsertarTelefono` (IN `p_id_usuario` INT, IN `p_telefono` VARCHAR(30))   BEGIN
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPInsertPasswordReset` (IN `p_id_usuario` INT, IN `p_token` VARCHAR(64), IN `p_expires_at` DATETIME)   BEGIN
    INSERT INTO password_resets (id_usuario, token, expires_at)
    VALUES (p_id_usuario, p_token, p_expires_at);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPRegistrarUsuario` (IN `p_user` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_password` VARCHAR(255))   BEGIN
    INSERT INTO usuarios (usuario_nombre, email, contraseña)
    VALUES (p_user, p_email, p_password);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPResetPasswordAndDeleteToken` (IN `p_token` VARCHAR(64), IN `p_new_password` VARCHAR(255))   BEGIN
    DECLARE v_id_usuario INT;

    -- Obtener el ID del usuario con ese token
    SELECT id_usuario INTO v_id_usuario
    FROM password_resets
    WHERE token = p_token;

    -- Actualizar contraseña
    UPDATE usuarios
    SET contraseña = p_new_password
    WHERE id_usuario = v_id_usuario;

    -- Eliminar token
    DELETE FROM password_resets
    WHERE token = p_token;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPUserExists` (IN `p_email` VARCHAR(64))   BEGIN
SELECT usuario_nombre FROM usuarios WHERE email = p_email;
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
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

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
-- Estructura de tabla para la tabla `carrito`
--

CREATE TABLE `carrito` (
  `id_carrito` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `fecha_creacion` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `carrito_items`
--

CREATE TABLE `carrito_items` (
  `id_item` int(11) NOT NULL,
  `id_carrito` int(11) DEFAULT NULL,
  `id_paquete` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `imagen_usuario` varchar(255) DEFAULT NULL,
  `id_pasajero` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
-- Estructura de tabla para la tabla `opiniones`
--

CREATE TABLE `opiniones` (
  `id_opinion` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `opinion` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `paquetes`
--

CREATE TABLE `paquetes` (
  `id_paquete` int(11) NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `destino` varchar(200) DEFAULT NULL,
  `fecha_salida` date DEFAULT NULL,
  `fecha_regreso` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `paquetes`
--

INSERT INTO `paquetes` (`id_paquete`, `nombre`, `descripcion`, `precio`, `destino`, `fecha_salida`, `fecha_regreso`) VALUES
(1, 'Paquete Caribe', 'Vacaciones en el Caribe todo incluido', 350000.00, 'Caribe', '2025-07-10', '2025-07-20');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `paquetes_alojamientos`
--

CREATE TABLE `paquetes_alojamientos` (
  `id_paquete` int(11) NOT NULL,
  `id_alojamiento` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `paquetes_destinos`
--

CREATE TABLE `paquetes_destinos` (
  `id_paquete` int(11) NOT NULL,
  `id_destino` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `paquetes_transportes`
--

CREATE TABLE `paquetes_transportes` (
  `id_paquete` int(11) NOT NULL,
  `id_transporte` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

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
-- Estructura de tabla para la tabla `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `token` varchar(64) NOT NULL,
  `expires_at` datetime NOT NULL,
  `creado_en` timestamp NOT NULL DEFAULT current_timestamp()
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
  `usuario_nombre` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `contraseña` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `usuario_nombre`, `email`, `contraseña`) VALUES
(39, 'Hooooooz', 'safarakiri@gmail.com', '$2y$10$SEniOT3UB6n.3saPrQFJEuoWeP/RvmmiZktxmi3vb8OXwb6mdWYQm');

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
  ADD KEY `id_paquete` (`id_paquete`);

--
-- Indices de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD PRIMARY KEY (`id_dato`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_pasajero` (`id_pasajero`);

--
-- Indices de la tabla `destinos`
--
ALTER TABLE `destinos`
  ADD PRIMARY KEY (`id_destino`);

--
-- Indices de la tabla `facturacion`
--
ALTER TABLE `facturacion`
  ADD PRIMARY KEY (`id_factura`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `opiniones`
--
ALTER TABLE `opiniones`
  ADD PRIMARY KEY (`id_opinion`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `paquetes`
--
ALTER TABLE `paquetes`
  ADD PRIMARY KEY (`id_paquete`);

--
-- Indices de la tabla `paquetes_alojamientos`
--
ALTER TABLE `paquetes_alojamientos`
  ADD PRIMARY KEY (`id_paquete`,`id_alojamiento`),
  ADD KEY `id_alojamiento` (`id_alojamiento`);

--
-- Indices de la tabla `paquetes_destinos`
--
ALTER TABLE `paquetes_destinos`
  ADD PRIMARY KEY (`id_paquete`,`id_destino`),
  ADD KEY `id_destino` (`id_destino`);

--
-- Indices de la tabla `paquetes_transportes`
--
ALTER TABLE `paquetes_transportes`
  ADD PRIMARY KEY (`id_paquete`,`id_transporte`),
  ADD KEY `id_transporte` (`id_transporte`);

--
-- Indices de la tabla `pasajeros`
--
ALTER TABLE `pasajeros`
  ADD PRIMARY KEY (`id_pasajero`),
  ADD UNIQUE KEY `dni` (`dni`);

--
-- Indices de la tabla `password_resets`
--
ALTER TABLE `password_resets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD PRIMARY KEY (`id_reserva`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_paquete` (`id_paquete`);

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
  ADD UNIQUE KEY `email` (`email`);

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
-- AUTO_INCREMENT de la tabla `carrito`
--
ALTER TABLE `carrito`
  MODIFY `id_carrito` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `carrito_items`
--
ALTER TABLE `carrito_items`
  MODIFY `id_item` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  MODIFY `id_dato` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `destinos`
--
ALTER TABLE `destinos`
  MODIFY `id_destino` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `facturacion`
--
ALTER TABLE `facturacion`
  MODIFY `id_factura` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `opiniones`
--
ALTER TABLE `opiniones`
  MODIFY `id_opinion` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `paquetes`
--
ALTER TABLE `paquetes`
  MODIFY `id_paquete` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `pasajeros`
--
ALTER TABLE `pasajeros`
  MODIFY `id_pasajero` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `reservas`
--
ALTER TABLE `reservas`
  MODIFY `id_reserva` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `tarjeta`
--
ALTER TABLE `tarjeta`
  MODIFY `id_tarjeta` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `transportes`
--
ALTER TABLE `transportes`
  MODIFY `id_transporte` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;

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
  ADD CONSTRAINT `carrito_items_ibfk_2` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`);

--
-- Filtros para la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD CONSTRAINT `datos_personales_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE,
  ADD CONSTRAINT `datos_personales_ibfk_2` FOREIGN KEY (`id_pasajero`) REFERENCES `pasajeros` (`id_pasajero`) ON DELETE SET NULL;

--
-- Filtros para la tabla `facturacion`
--
ALTER TABLE `facturacion`
  ADD CONSTRAINT `facturacion_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `opiniones`
--
ALTER TABLE `opiniones`
  ADD CONSTRAINT `opiniones_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;

--
-- Filtros para la tabla `paquetes_alojamientos`
--
ALTER TABLE `paquetes_alojamientos`
  ADD CONSTRAINT `paquetes_alojamientos_ibfk_1` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`),
  ADD CONSTRAINT `paquetes_alojamientos_ibfk_2` FOREIGN KEY (`id_alojamiento`) REFERENCES `alojamientos` (`id_alojamiento`);

--
-- Filtros para la tabla `paquetes_destinos`
--
ALTER TABLE `paquetes_destinos`
  ADD CONSTRAINT `paquetes_destinos_ibfk_1` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`),
  ADD CONSTRAINT `paquetes_destinos_ibfk_2` FOREIGN KEY (`id_destino`) REFERENCES `destinos` (`id_destino`);

--
-- Filtros para la tabla `paquetes_transportes`
--
ALTER TABLE `paquetes_transportes`
  ADD CONSTRAINT `paquetes_transportes_ibfk_1` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`),
  ADD CONSTRAINT `paquetes_transportes_ibfk_2` FOREIGN KEY (`id_transporte`) REFERENCES `transportes` (`id_transporte`);

--
-- Filtros para la tabla `password_resets`
--
ALTER TABLE `password_resets`
  ADD CONSTRAINT `password_resets_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Filtros para la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD CONSTRAINT `reservas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `reservas_ibfk_2` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`);

--
-- Filtros para la tabla `tarjeta`
--
ALTER TABLE `tarjeta`
  ADD CONSTRAINT `tarjeta_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
