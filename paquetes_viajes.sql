-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 13-06-2025 a las 20:54:20
-- Versión del servidor: 10.4.28-MariaDB
-- Versión de PHP: 8.0.28

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

CREATE DEFINER=`root`@`localhost` PROCEDURE `SPRegistrarUsuario` (IN `p_nombre` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_password` VARCHAR(255))   BEGIN
    INSERT INTO usuarios (nombre, email, contraseña)
    VALUES (p_nombre, p_email, p_password);
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
  `nombre` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `contraseña` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Volcado de datos para la tabla `usuarios`
--

INSERT INTO `usuarios` (`id_usuario`, `nombre`, `email`, `contraseña`) VALUES
(1, 'Usuario Prueba', 'usuario@test.com', '123456');

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
-- Indices de la tabla `destinos`
--
ALTER TABLE `destinos`
  ADD PRIMARY KEY (`id_destino`);

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
-- Indices de la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD PRIMARY KEY (`id_reserva`),
  ADD KEY `id_usuario` (`id_usuario`),
  ADD KEY `id_paquete` (`id_paquete`);

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
-- AUTO_INCREMENT de la tabla `destinos`
--
ALTER TABLE `destinos`
  MODIFY `id_destino` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `paquetes`
--
ALTER TABLE `paquetes`
  MODIFY `id_paquete` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `reservas`
--
ALTER TABLE `reservas`
  MODIFY `id_reserva` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `transportes`
--
ALTER TABLE `transportes`
  MODIFY `id_transporte` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `usuarios`
--
ALTER TABLE `usuarios`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

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
-- Filtros para la tabla `reservas`
--
ALTER TABLE `reservas`
  ADD CONSTRAINT `reservas_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios` (`id_usuario`),
  ADD CONSTRAINT `reservas_ibfk_2` FOREIGN KEY (`id_paquete`) REFERENCES `paquetes` (`id_paquete`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
