-- ============================================================
-- SCRIPTS SQL - Sistema de Control de Operaciones de Renta de Vehículos
-- ============================================================
-- Descripción: Scripts de creación de tablas, índices, constraints,
--              procedimientos almacenados y vistas para el sistema.
-- Base de datos: MySQL 8.0+
-- ============================================================

-- ============================================================
-- SECCIÓN 1: CREACIÓN DE TABLAS
-- ============================================================

-- Tabla de Clientes
CREATE TABLE IF NOT EXISTS clientes (
    id_cliente      BIGINT          NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(200)    NOT NULL,
    rfc             VARCHAR(20)     NOT NULL,
    correo          VARCHAR(100)    NOT NULL,
    telefono        VARCHAR(20),
    activo          TINYINT(1)      NOT NULL DEFAULT 1,
    fecha_creacion  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_clientes PRIMARY KEY (id_cliente),
    CONSTRAINT uq_clientes_rfc UNIQUE (rfc),
    CONSTRAINT uq_clientes_correo UNIQUE (correo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Usuarios (Ejecutivos, Admins)
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario      BIGINT          NOT NULL AUTO_INCREMENT,
    nombre          VARCHAR(200)    NOT NULL,
    correo          VARCHAR(100)    NOT NULL,
    rol             ENUM('EJECUTIVO','ADMIN','SUPERVISOR') NOT NULL DEFAULT 'EJECUTIVO',
    activo          TINYINT(1)      NOT NULL DEFAULT 1,
    fecha_creacion  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuarios_correo UNIQUE (correo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Inventario (Vehículos)
CREATE TABLE IF NOT EXISTS inventario (
    id_inventario       BIGINT          NOT NULL AUTO_INCREMENT,
    numero_serie        VARCHAR(50)     NOT NULL,
    placa               VARCHAR(20)     NOT NULL,
    modelo              VARCHAR(100)    NOT NULL,
    marca               VARCHAR(100)    NOT NULL,
    anio                INT             NOT NULL,
    color               VARCHAR(50),
    estado              ENUM('DISPONIBLE','EN_PROCESO','APARTADO','RENTADO','VENDIDO','NO_DISPONIBLE')
                        NOT NULL DEFAULT 'DISPONIBLE',
    id_operacion_activa BIGINT,  -- FK a operaciones (se agrega constraint más abajo)
    fecha_estado        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_creacion      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_inventario PRIMARY KEY (id_inventario),
    CONSTRAINT uq_inventario_serie UNIQUE (numero_serie),
    CONSTRAINT uq_inventario_placa UNIQUE (placa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Operaciones
CREATE TABLE IF NOT EXISTS operaciones (
    id_operacion            BIGINT          NOT NULL AUTO_INCREMENT,
    cun                     VARCHAR(20)     NOT NULL,
    id_cliente              BIGINT          NOT NULL,
    id_ejecutivo            BIGINT          NOT NULL,
    estado                  ENUM('COTIZACION','CONFIRMADA','EN_RENTA','FINALIZADA','CANCELADA')
                            NOT NULL DEFAULT 'COTIZACION',
    fecha_inicio_esperada   DATE            NOT NULL,
    fecha_fin_esperada      DATE            NOT NULL,
    fecha_confirmacion      DATETIME,
    fecha_creacion          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_operaciones PRIMARY KEY (id_operacion),
    CONSTRAINT uq_operaciones_cun UNIQUE (cun),
    CONSTRAINT fk_operaciones_cliente FOREIGN KEY (id_cliente)
        REFERENCES clientes(id_cliente),
    CONSTRAINT fk_operaciones_ejecutivo FOREIGN KEY (id_ejecutivo)
        REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_operaciones_fechas CHECK (fecha_fin_esperada >= fecha_inicio_esperada)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Agregar FK de inventario a operaciones (después de crear operaciones)
ALTER TABLE inventario
    ADD CONSTRAINT fk_inventario_operacion
    FOREIGN KEY (id_operacion_activa)
    REFERENCES operaciones(id_operacion)
    ON DELETE SET NULL;

-- Tabla de OPERACION_UNIDADES
CREATE TABLE IF NOT EXISTS operacion_unidades (
    id_opun             BIGINT          NOT NULL AUTO_INCREMENT,
    id_operacion        BIGINT          NOT NULL,
    id_inventario       BIGINT          NOT NULL,
    estado              ENUM('EN_PROCESO','VENCIDA','CONFIRMADA','EN_RENTA','FINALIZADA','CANCELADA','RESERVADA')
                        NOT NULL DEFAULT 'EN_PROCESO',
    fecha_agregada      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_vencimiento   DATETIME        NOT NULL,  -- fecha_agregada + 15 min
    fecha_confirmada    DATETIME,
    fecha_checkin       DATETIME,
    fecha_checkout      DATETIME,
    observaciones       TEXT,
    fecha_actualizacion DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT pk_operacion_unidades PRIMARY KEY (id_opun),
    CONSTRAINT fk_opun_operacion FOREIGN KEY (id_operacion)
        REFERENCES operaciones(id_operacion),
    CONSTRAINT fk_opun_inventario FOREIGN KEY (id_inventario)
        REFERENCES inventario(id_inventario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Periodos de Operación
CREATE TABLE IF NOT EXISTS operacion_periodos (
    id_periodo      BIGINT          NOT NULL AUTO_INCREMENT,
    id_operacion    BIGINT          NOT NULL,
    fecha_inicio    DATE            NOT NULL,
    fecha_fin       DATE            NOT NULL,
    estado          ENUM('ACTIVO','COMPLETADO','CANCELADO') NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_operacion_periodos PRIMARY KEY (id_periodo),
    CONSTRAINT fk_periodos_operacion FOREIGN KEY (id_operacion)
        REFERENCES operaciones(id_operacion),
    CONSTRAINT chk_periodos_fechas CHECK (fecha_fin >= fecha_inicio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Unidades por Periodo
CREATE TABLE IF NOT EXISTS operacion_periodo_unidades (
    id_periodo_unidad   BIGINT          NOT NULL AUTO_INCREMENT,
    id_periodo          BIGINT          NOT NULL,
    id_inventario       BIGINT          NOT NULL,
    estado              ENUM('ACTIVO','COMPLETADO','CANCELADO') NOT NULL DEFAULT 'ACTIVO',
    fecha_checkin       DATETIME,
    fecha_checkout      DATETIME,
    fecha_creacion      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_periodo_unidades PRIMARY KEY (id_periodo_unidad),
    CONSTRAINT fk_pu_periodo FOREIGN KEY (id_periodo)
        REFERENCES operacion_periodos(id_periodo),
    CONSTRAINT fk_pu_inventario FOREIGN KEY (id_inventario)
        REFERENCES inventario(id_inventario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de Historial de Estados (Auditoría)
CREATE TABLE IF NOT EXISTS historial_estados (
    id_historial        BIGINT          NOT NULL AUTO_INCREMENT,
    entidad             VARCHAR(50)     NOT NULL,
    id_entidad          BIGINT          NOT NULL,
    estado_anterior     VARCHAR(50)     NOT NULL,
    estado_nuevo        VARCHAR(50)     NOT NULL,
    id_usuario          BIGINT,  -- NULL si fue cambio automático (Job)
    motivo              VARCHAR(500)    NOT NULL,
    fecha_cambio        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_historial PRIMARY KEY (id_historial),
    CONSTRAINT fk_historial_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tabla de control de ejecuciones del Job
CREATE TABLE IF NOT EXISTS job_executions (
    id_execution        BIGINT          NOT NULL AUTO_INCREMENT,
    job_nombre          VARCHAR(100)    NOT NULL,
    fecha_inicio        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin           DATETIME,
    registros_procesados INT            NOT NULL DEFAULT 0,
    estado              ENUM('EJECUTANDO','COMPLETADO','ERROR') NOT NULL DEFAULT 'EJECUTANDO',
    mensaje_error       TEXT,
    CONSTRAINT pk_job_executions PRIMARY KEY (id_execution)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- SECCIÓN 2: ÍNDICES
-- ============================================================

-- Índices para búsquedas frecuentes en inventario
CREATE INDEX idx_inventario_estado
    ON inventario(estado);

CREATE INDEX idx_inventario_op_activa
    ON inventario(id_operacion_activa);

-- Índices para operacion_unidades
CREATE INDEX idx_opun_operacion
    ON operacion_unidades(id_operacion);

CREATE INDEX idx_opun_inventario
    ON operacion_unidades(id_inventario);

CREATE INDEX idx_opun_estado
    ON operacion_unidades(estado);

CREATE INDEX idx_opun_vencimiento
    ON operacion_unidades(fecha_vencimiento, estado);  -- Job Scheduler usa este

CREATE INDEX idx_opun_inv_estado
    ON operacion_unidades(id_inventario, estado);  -- Para buscar RESERVADAS de una unidad

-- Índices para historial
CREATE INDEX idx_historial_entidad
    ON historial_estados(entidad, id_entidad);

CREATE INDEX idx_historial_fecha
    ON historial_estados(fecha_cambio);

-- Índices para operaciones
CREATE INDEX idx_operaciones_estado
    ON operaciones(estado);

CREATE INDEX idx_operaciones_cliente
    ON operaciones(id_cliente);

-- ============================================================
-- SECCIÓN 3: PROCEDIMIENTOS ALMACENADOS
-- ============================================================

DELIMITER //

-- Procedimiento: Agregar unidad a cotización
CREATE PROCEDURE sp_agregar_unidad_operacion(
    IN p_id_operacion   BIGINT,
    IN p_id_inventario  BIGINT,
    IN p_id_usuario     BIGINT,
    OUT p_resultado     VARCHAR(50),
    OUT p_mensaje       VARCHAR(500)
)
BEGIN
    DECLARE v_inv_estado VARCHAR(50);
    DECLARE v_inv_op_activa BIGINT;
    DECLARE v_id_opun BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Error interno al procesar la solicitud';
    END;
    
    -- Validar estado del inventario
    SELECT estado, id_operacion_activa
    INTO v_inv_estado, v_inv_op_activa
    FROM inventario
    WHERE id_inventario = p_id_inventario
    FOR UPDATE;
    
    IF v_inv_estado IS NULL THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'INV-001: Unidad no encontrada';
    ELSEIF v_inv_estado != 'DISPONIBLE' THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = CONCAT('INV-002: Unidad no disponible. Estado actual: ', v_inv_estado);
    ELSEIF v_inv_op_activa IS NOT NULL THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = CONCAT('INV-003: Unidad ya tiene operación activa: ', v_inv_op_activa);
    ELSE
        START TRANSACTION;
        
        -- Insertar en operacion_unidades
        INSERT INTO operacion_unidades (id_operacion, id_inventario, estado, fecha_agregada, fecha_vencimiento)
        VALUES (p_id_operacion, p_id_inventario, 'EN_PROCESO', NOW(), DATE_ADD(NOW(), INTERVAL 15 MINUTE));
        
        SET v_id_opun = LAST_INSERT_ID();
        
        -- Actualizar inventario
        UPDATE inventario
        SET estado = 'EN_PROCESO',
            id_operacion_activa = p_id_operacion,
            fecha_estado = NOW()
        WHERE id_inventario = p_id_inventario;
        
        -- Registrar en historial
        INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, motivo)
        VALUES ('INVENTARIO', p_id_inventario, 'DISPONIBLE', 'EN_PROCESO', p_id_usuario, 'Unidad agregada a cotización');
        
        INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, motivo)
        VALUES ('OPERACION_UNIDADES', v_id_opun, 'NUEVA', 'EN_PROCESO', p_id_usuario, 'Unidad agregada a cotización');
        
        COMMIT;
        
        SET p_resultado = 'OK';
        SET p_mensaje = CONCAT('Unidad agregada. Vence en 15 min. id_opun: ', v_id_opun);
    END IF;
END //

-- Procedimiento: Job de vencimiento automático
CREATE PROCEDURE sp_job_vencimiento(
    OUT p_procesados    INT
)
BEGIN
    DECLARE v_id_opun       BIGINT;
    DECLARE v_id_inventario BIGINT;
    DECLARE v_done          TINYINT DEFAULT 0;
    DECLARE v_count         INT DEFAULT 0;
    
    DECLARE c_vencidas CURSOR FOR
        SELECT id_opun, id_inventario
        FROM operacion_unidades
        WHERE estado = 'EN_PROCESO'
          AND fecha_vencimiento < NOW()
        FOR UPDATE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    OPEN c_vencidas;
    
    loop_vencidas: LOOP
        FETCH c_vencidas INTO v_id_opun, v_id_inventario;
        
        IF v_done THEN
            LEAVE loop_vencidas;
        END IF;
        
        -- Actualizar OPUN a VENCIDA
        UPDATE operacion_unidades
        SET estado = 'VENCIDA'
        WHERE id_opun = v_id_opun AND estado = 'EN_PROCESO';
        
        -- Liberar inventario
        UPDATE inventario
        SET estado = 'DISPONIBLE',
            id_operacion_activa = NULL,
            fecha_estado = NOW()
        WHERE id_inventario = v_id_inventario
          AND estado = 'EN_PROCESO';
        
        -- Registrar historial
        INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, motivo)
        VALUES ('OPERACION_UNIDADES', v_id_opun, 'EN_PROCESO', 'VENCIDA', NULL, 'Job Scheduler - Vencimiento automático');
        
        INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, motivo)
        VALUES ('INVENTARIO', v_id_inventario, 'EN_PROCESO', 'DISPONIBLE', NULL, 'Job Scheduler - Liberación por vencimiento');
        
        SET v_count = v_count + 1;
    END LOOP;
    
    CLOSE c_vencidas;
    COMMIT;
    
    SET p_procesados = v_count;
END //

-- Procedimiento: Reactivar unidad reservada
CREATE PROCEDURE sp_reactivar_reservada(
    IN p_id_operacion   BIGINT,
    IN p_id_inventario  BIGINT,
    IN p_id_usuario     BIGINT,
    OUT p_resultado     VARCHAR(50),
    OUT p_mensaje       VARCHAR(500)
)
BEGIN
    DECLARE v_inv_estado    VARCHAR(50);
    DECLARE v_opun_estado   VARCHAR(50);
    DECLARE v_id_opun       BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Error interno al reactivar la unidad';
    END;
    
    -- Validar estado de inventario
    SELECT estado INTO v_inv_estado
    FROM inventario
    WHERE id_inventario = p_id_inventario
    FOR UPDATE;
    
    -- Validar OPUN
    SELECT estado, id_opun INTO v_opun_estado, v_id_opun
    FROM operacion_unidades
    WHERE id_inventario = p_id_inventario
      AND id_operacion = p_id_operacion
      AND estado = 'RESERVADA'
    FOR UPDATE;
    
    IF v_inv_estado != 'DISPONIBLE' THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = CONCAT('La unidad no está disponible. Estado INV: ', IFNULL(v_inv_estado, 'No encontrada'));
    ELSEIF v_opun_estado IS NULL THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'No se encontró OPUN en estado RESERVADA para esta unidad/operación';
    ELSE
        START TRANSACTION;
        
        -- Reactivar OPUN
        UPDATE operacion_unidades
        SET estado = 'CONFIRMADA',
            fecha_confirmada = NOW()
        WHERE id_opun = v_id_opun AND estado = 'RESERVADA';
        
        -- Apartar inventario
        UPDATE inventario
        SET estado = 'APARTADO',
            id_operacion_activa = p_id_operacion,
            fecha_estado = NOW()
        WHERE id_inventario = p_id_inventario AND estado = 'DISPONIBLE';
        
        -- Registrar historial
        INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, motivo)
        VALUES ('OPERACION_UNIDADES', v_id_opun, 'RESERVADA', 'CONFIRMADA', p_id_usuario, 'Reactivación de unidad reservada');
        
        INSERT INTO historial_estados (entidad, id_entidad, estado_anterior, estado_nuevo, id_usuario, motivo)
        VALUES ('INVENTARIO', p_id_inventario, 'DISPONIBLE', 'APARTADO', p_id_usuario, 'Reactivación de unidad reservada');
        
        COMMIT;
        
        SET p_resultado = 'OK';
        SET p_mensaje = 'Unidad reactivada exitosamente. Lista para checkin.';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- SECCIÓN 4: VISTAS
-- ============================================================

-- Vista: Estado actual del inventario con operación activa
CREATE OR REPLACE VIEW v_inventario_estado AS
SELECT
    i.id_inventario,
    i.numero_serie,
    i.placa,
    CONCAT(i.marca, ' ', i.modelo, ' ', i.anio) AS descripcion,
    i.estado AS inv_estado,
    i.id_operacion_activa,
    o.cun,
    o.estado AS op_estado,
    i.fecha_estado
FROM inventario i
LEFT JOIN operaciones o ON i.id_operacion_activa = o.id_operacion;

-- Vista: Unidades en proceso con tiempo restante
CREATE OR REPLACE VIEW v_unidades_en_proceso AS
SELECT
    ou.id_opun,
    ou.id_operacion,
    op.cun,
    ou.id_inventario,
    i.placa,
    ou.estado,
    ou.fecha_agregada,
    ou.fecha_vencimiento,
    TIMESTAMPDIFF(SECOND, NOW(), ou.fecha_vencimiento) AS segundos_restantes,
    CASE
        WHEN TIMESTAMPDIFF(SECOND, NOW(), ou.fecha_vencimiento) <= 0 THEN 'VENCIDA'
        WHEN TIMESTAMPDIFF(SECOND, NOW(), ou.fecha_vencimiento) <= 300 THEN 'CRITICA'
        ELSE 'VIGENTE'
    END AS alerta
FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
INNER JOIN operaciones op ON ou.id_operacion = op.id_operacion
WHERE ou.estado = 'EN_PROCESO';

-- Vista: Unidades reservadas disponibles para reactivar
CREATE OR REPLACE VIEW v_reservadas_disponibles AS
SELECT
    ou.id_opun,
    ou.id_operacion,
    op.cun,
    u.nombre AS ejecutivo,
    u.correo AS correo_ejecutivo,
    ou.id_inventario,
    i.placa,
    CONCAT(i.marca, ' ', i.modelo) AS vehiculo,
    ou.fecha_agregada AS fecha_reserva
FROM operacion_unidades ou
INNER JOIN inventario i ON ou.id_inventario = i.id_inventario
INNER JOIN operaciones op ON ou.id_operacion = op.id_operacion
INNER JOIN usuarios u ON op.id_ejecutivo = u.id_usuario
WHERE ou.estado = 'RESERVADA'
  AND i.estado = 'DISPONIBLE';

-- Vista: Dashboard de estados
CREATE OR REPLACE VIEW v_dashboard_estados AS
SELECT
    'INVENTARIO' AS entidad,
    estado,
    COUNT(*) AS cantidad
FROM inventario
GROUP BY estado
UNION ALL
SELECT
    'OPERACION_UNIDADES' AS entidad,
    estado,
    COUNT(*) AS cantidad
FROM operacion_unidades
GROUP BY estado;

-- ============================================================
-- SECCIÓN 5: DATOS DE EJEMPLO (para pruebas)
-- ============================================================

-- Insertar usuario de prueba
INSERT INTO usuarios (nombre, correo, rol) VALUES
    ('Ana García', 'ana.garcia@empresa.com', 'EJECUTIVO'),
    ('Admin Sistema', 'admin@empresa.com', 'ADMIN'),
    ('Luis Torres', 'luis.torres@empresa.com', 'EJECUTIVO');

-- Insertar cliente de prueba
INSERT INTO clientes (nombre, rfc, correo, telefono) VALUES
    ('Empresa XYZ S.A. de C.V.', 'EXY001122ABC', 'contacto@empresa-xyz.com', '555-0100'),
    ('Corporativo ABC', 'CAB990011XYZ', 'admin@corporativo-abc.com', '555-0200');

-- Insertar vehículos de prueba
INSERT INTO inventario (numero_serie, placa, modelo, marca, anio, color, estado) VALUES
    ('VIN-001', 'ABC-123', 'Sedán EX', 'Toyota', 2023, 'Blanco', 'DISPONIBLE'),
    ('VIN-002', 'DEF-456', 'SUV Sport', 'Honda', 2022, 'Negro', 'DISPONIBLE'),
    ('VIN-003', 'GHI-789', 'Camioneta', 'Ford', 2021, 'Gris', 'DISPONIBLE'),
    ('VIN-004', 'JKL-012', 'Compacto', 'Nissan', 2023, 'Rojo', 'DISPONIBLE'),
    ('VIN-005', 'MNO-345', 'SUV Premium', 'BMW', 2022, 'Azul', 'DISPONIBLE');

-- ============================================================
-- SECCIÓN 6: TRIGGER OPCIONAL - Validación de integridad
-- ============================================================

DELIMITER //

-- Trigger: Prevenir cambio de estado inválido en INVENTARIO
CREATE TRIGGER trg_inventario_estado_before_update
BEFORE UPDATE ON inventario
FOR EACH ROW
BEGIN
    -- Prevenir que VENDIDO o NO_DISPONIBLE cambien a otro estado activo
    IF OLD.estado IN ('VENDIDO', 'NO_DISPONIBLE') AND
       NEW.estado NOT IN ('VENDIDO', 'NO_DISPONIBLE') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede cambiar estado desde VENDIDO o NO_DISPONIBLE';
    END IF;
END //

DELIMITER ;

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
