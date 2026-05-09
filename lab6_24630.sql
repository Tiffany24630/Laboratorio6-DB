-- Tiffany Salazar Suarez   24630   Lab6

-- 1. Rol vendedores
CREATE ROLE vendedores;

GRANT SELECT ON TABLE productos TO vendedores;
GRANT INSERT ON TABLE pedidos, detalle_pedido TO vendedores;

CREATE ROLE maria LOGIN PASSWORD 'vendedora1';
CREATE ROLE juan LOGIN PASSWORD 'vendedor2';

GRANT vendedores TO maria, juan;


-- 2. Auditor
CREATE ROLE auditor LOGIN PASSWORD 'auditorExterno'
VALID UNTIL '2026-11-10';




