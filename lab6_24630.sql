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
        'Stock insuficiente';
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

-- 10. Validación de inventario
CREATE OR REPLACE FUNCTION validar_stock()
RETURNS TRIGGER AS 
$$ 
DECLARE 
    v_stock INT;

BEGIN
    SELECT stock INTO v_stock
    FROM productos WHERE id_producto = NEW.id_producto;

    IF v_stock <= 0 THEN
        RAISE EXCEPTION
        'Producto sin inventario';
    END IF;

    RETURN NEW;

END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_stock
BEFORE INSERT ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION validar_stock();

-- 11. Descontar inventario
CREATE OR REPLACE FUNCTION descontar_stock()
RETURNS TRIGGER AS
$$

BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    RETURN NEW;

END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trg_desconectar_stock
AFTER INSERT ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION descontar_stock();

-- 12. Actualizar total del pedido
CREATE OR REPLACE FUNCTION actualizar_total_pedido()
RETURNS TRIGGER AS
$$

BEGIN
    UPDATE pedidos
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM detalle_pedido WHERE id_pedido = NEW.id_pedido
    )
    WHERE id_pedido = NEW.id_pedido;

    RETURN NEW;

END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_total
AFTER INSERT ON detalle_pedido 
FOR EACH ROW EXECUTE FUNCTION actualizar_total_pedido();

-- 13. Auditoria de inventario
CREATE OR REPLACE FUNCTION auditoria_inventario()
RETURNS TRIGGER AS
$$ 

BEGIN 
    INSERT INTO auditoria_stock(id_producto, stock_anterior, stock_nuevo, fecha)
    VALUES(OLD.id_producto, OLD.stock, NEW.stock, NOW());

    RETURN NEW;

END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_inventario
AFTER UPDATE ON productos
FOR EACH ROW EXECUTE FUNCTION auditoria_inventario();

-- 14. Validación de monto de pago
CREATE OR REPLACE FUNCTION validar_pago()
RETURNS TRIGGER AS
$$
DECLARE
    v_total DECIMAL;

BEGIN
    SELECT total INTO v_total
    FROM pedidos WHERE id_pedido = NEW.id_pedido;

    IF NEW.monto <> v_total THEN
        RAISE EXCEPTION
        'El monto no coincide con el total del pedido';
    END IF;

    RETURN NEW;

END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_pago
BEFORE INSERT ON pagos 
FOR EACH ROW EXECUTE FUNCTION validar_pago();
