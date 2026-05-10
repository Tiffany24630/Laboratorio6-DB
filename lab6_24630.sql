-- Tiffany Salazar Suarez   24630   Lab6

-- 1. Rol vendedores
CREATE ROLE vendedores;

GRANT CONNECT ON DATABASE tienda_db TO vendedores;
GRANT USAGE ON SCHEMA public TO vendedores;
GRANT SELECT ON TABLE productos TO vendedores;
GRANT INSERT ON TABLE pedidos, detalle_pedido TO vendedores;

CREATE ROLE maria LOGIN PASSWORD 'vendedora1';
CREATE ROLE juan LOGIN PASSWORD 'vendedor2';

GRANT vendedores TO maria;
GRANT vendedores TO juan;

-- 2. Auditor
CREATE ROLE auditor LOGIN PASSWORD 'auditorExterno'
VALID UNTIL '2026-11-10';

GRANT CONNECT ON DATABASE tienda_db TO auditor;
GRANT USAGE ON SCHEMA public TO auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO auditor;

-- 3. Revocar permisos en vendedores para acceder a clientes
GRANT SELECT ON TABLE clientes TO vendedores;

REVOKE SELECT ON TABLE clientes FROM vendedores;

-- 4. Vista clientes activos para vendedores
CREATE VIEW vista_clientesActivos AS
SELECT id_cliente, nombre, email FROM clientes
WHERE activo = TRUE;

GRANT SELECT ON vista_clientesActivos TO vendedores;

-- 5. Revocar permisos en vendedores para insertar en la tabla
REVOKE INSERT ON TABLE pedidos FROM vendedores;

-- 6. Función que devuelve productos
CREATE OR REPLACE FUNCTION obtener_productos_disponibles()
RETURNS TABLE(id_producto INT, nombre VARCHAR, precio DECIMAL, stock INT)
AS $$ BEGIN RETURN QUERY SELECT p.id_producto, p.nombre, p.precio, p.stock 
FROM productos p WHERE p.stock > 0;

END;
$$ LANGUAGE plpgsql;

SELECT * FROM obtener_productos_disponibles();

-- 7. Crear función para activar cliente
CREATE OR REPLACE FUNCTION activar_cliente(p_id_cliente INT)
RETURNS TEXT AS $$ DECLARE estado_actual BOOLEAN;

BEGIN 
SELECT activo INTO estado_actual 
FROM clientes WHERE id_cliente = p_id_cliente;

IF estado_actual IS NULL THEN
    RETURN 'Cliente no existe';
END IF;

IF estado_actual = TRUE THEN
    RETURN 'Cliente ya está activo';
END IF;

UPDATE clientes SET activo = TRUE
WHERE id_cliente = p_id_cliente;

RETURN 'Cliente activado correctamente';

END;
$$ LANGUAGE plpgsql;

SELECT activar_cliente(1);

-- 8. Verificar disponibilidad del producto y estado de cliente
CREATE OR REPLACE PROCEDURE crear_pedido_seguro(p_id_cliente INT, p_id_producto INT, p_cantidad INT)
LANGUAGE plpgsql AS
$$ 
DECLARE
v_stock INT;
v_precio DECIMAL;
v_activo BOOLEAN;
v_total DECIMAL;
v_id_pedido INT;

BEGIN
SELECT activo INTO v_activo
FROM clientes WHERE id_cliente = p_id_cliente;

IF v_activo IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION
    'Cliente inactivo o existente';
END IF;

SELECT stock, precio INTO v_stock, v_precio
FROM productos WHERE id_producto = p_id_producto;

IF v_stock < p_cantidad THEN
    RAISE EXCEPTION
    'Stock insuficiente'
END IF;

v_total := v_precio * p_cantidad;

INSERT INTO pedidos(id_cliente, total) VALUES(p_id_cliente, v_total)
RETURNING id_pedido INTO v_id_pedido;

INSERT INTO detalle_pedido(id_pedido, id_producto, cantidad, subtotal) VALUES(v_id_pedido, p_id_producto, p_cantidd, v_total);

END; 
$$;

-- 9. Hacer segura la creación de pedidos
GRANT EXECUTE ON PROCEDURE crear_pedido_seguro TO vendedores;

REVOKE INSERT ON detalle_pedido FROM vendedores;
