-- CURSO SQL 
-- MARCOS GORTARI
-- TIENDA SCOTT
-- CREACION DE BASE DE DATOS, VISTAS, STORED, TRIGGERS

create database scott_patg;

use scott_patg;

-- Se crea tabla de cliente
create table clientes(
id_cliente int not null unique key auto_increment,
nombre varchar(50) not null,
apellido varchar(50) not null,
direccion varchar(50) not null,
email varchar(150) not null unique key,
primary key (id_cliente)
);

-- Se crea tabla de vendedores
create table vendedores(
id_vendedor int not null unique key auto_increment,
apellido varchar(50) not null,
primary key (id_vendedor)
);

-- Se crea tabla de productos de la tienda, para ingresar una factura con productos, los productos tienen que estar creados
create table productos(
id_codigo varchar(16) not null unique key,
id_descripcion varchar(32) not null,
descripcion_adicional varchar(10) not null,
primary key (id_codigo, id_descripcion)
);

-- Se crea tabla de proveedores, para poder agregarlos juntos con los productos
create table proveedores(
id_prov int unique key auto_increment,
razon_social varchar(12) not null unique key,
cuit varchar(30) not null unique key,
domicilio varchar(30) not null,
primary key (id_prov, razon_social)
);

-- Se crea tabla que se ingresa las facturas por proveedor, para poder ingresar las cantidades por productos
create table fact_provee(
id_prov int not null,
razon_social varchar(12) not null,
id_codigo varchar(16) not null,
id_precio decimal(9,2) not null,
cantidad int not null,
primary key (id_precio),
foreign key (id_prov, razon_social) references proveedores(id_prov, razon_social),
foreign key (id_codigo) references productos(id_codigo)
);

-- Se crea tabla de precios de los productos
create table precios(
id_codigo varchar(16) not null unique key,
id_precio decimal(9,2) not null,
foreign key (id_codigo, id_precio) references fact_provee (id_codigo, id_precio)
);

-- Se crea tabla de factura indicando el vendedor que la vendio
create table factura(
id_fecha date not null,
id_factura int not null unique key auto_increment,
id_cliente int not null,
id_vendedor int not null,
id_codigo varchar(16),
cantidad int not null,
id_precio decimal(9,2) not null,
total decimal (15,2),
primary key (id_factura, id_fecha),
foreign key (id_codigo, id_precio) references fact_provee(id_codigo, id_precio),
foreign key (id_cliente) references clientes(id_cliente),
foreign key (id_vendedor) references vendedores(id_vendedor)
);

-- Se crea tabla de los articulos facturados por el numero de factura
create table art_facturados(
id_factura int not null unique key,
id_codigo varchar(16) not null,
id_descripcion varchar(32) not null,
cantidad int not null,
id_precio decimal(9,2) not null,
foreign key (id_factura) references factura(id_factura),
foreign key(id_codigo, id_descripcion) references productos(id_codigo, id_descripcion),
foreign key(id_precio) references fact_provee (id_precio)
);

-- CREACION DE VISTAS
 
-- Visualizamos los productos por proveedor
create view proveedores_de_productos as
select razon_social, id_codigo
from fact_provee;

-- Visualizamos los art facturados por cantidad
create view detalle_art_fact as
select f.id_fecha,
	   f.id_factura,
	   af.id_codigo, 
	   af.id_descripcion, 
       af.cantidad
from art_facturados af
inner join factura f on af.id_factura = f.id_factura;

-- Visualizamos el detalle de la factura junto con el nombre del cliente
create view detalle_client as
select f.id_factura,
	   f.id_cliente,
       c.nombre,
       af.id_descripcion, 
       af.cantidad
from art_facturados af
inner join factura f on af.id_factura = f.id_factura
inner join clientes c on f.id_cliente = c.id_cliente; 

-- Visualizamos los precios por proveedores
create view precios_proveedores as
select
    pr.razon_social,
    p.id_codigo,
    p.id_precio    
from fact_provee pr
inner join precios p on pr.id_codigo = p.id_codigo;


-- FUNCIONES 
-- Creamos funciones para calcular el costo de los productos
delimiter $$

create function Civa (costo int)
returns decimal(9,2)
	NO SQL	
begin
	declare suma decimal(9,2);
    declare iva decimal(9,2);
    set iva = 21;
    set suma = (costo * iva / 100);
    return suma;
end$$

delimiter $$

create function Ccompra (costo int, iva int)
returns decimal(9,2)
	NO SQL
begin
	declare resta decimal(9,2);
    declare compra decimal(9,2);
    set compra = 1.6;
    set iva = 1.21;
    set resta = (costo / iva / compra);
    return resta;
end$$

-- TRIGGERS

-- Creamos un trigger donde buscamos insertar en la tabla precios el valor del producto, si el valor existe lo actualizaria.
DELIMITER $$
CREATE TRIGGER insert_precio
AFTER INSERT ON fact_provee
FOR EACH ROW
BEGIN
    DECLARE precio_existente INT;
    
    -- Verifica si los datos ya existen en la tabla precios
    SELECT COUNT(*) INTO precio_existente
    FROM precios
    WHERE id_codigo = NEW.id_codigo;
    
    -- Si los datos no existen, realiza la inserción
    IF precio_existente = 0 THEN
        INSERT INTO precios (id_codigo, id_precio)
        VALUES (NEW.id_codigo, NEW.id_precio);
    ELSE
        -- Si los datos ya existen, actualiza el valor del precio
        UPDATE precios
        SET id_precio = NEW.id_precio
        WHERE id_codigo = NEW.id_codigo;
    END IF;
END$$

DELIMITER ;

-- Creamos un trigger donde calculamos el total de la factura
DELIMITER $$
CREATE TRIGGER calcular_el_total
BEFORE INSERT ON factura
FOR EACH ROW
BEGIN
    DECLARE precio_unitario DECIMAL(9,2);
    -- buscamos el precio unitario seleccionando de la fact_provee
    SELECT id_precio INTO precio_unitario
    FROM fact_provee
    WHERE id_codigo = NEW.id_codigo
    LIMIT 1;

    -- Si no se encuentra el precio unitario, seteamos el valor a 0
    IF precio_unitario IS NULL THEN
        SET precio_unitario = 0.00; 
    END IF;

    -- Calcula el precio unitario por el iva y la ganancia del 60%, luego lo coloca de forma automatica en al columna total
    SET NEW.total = NEW.cantidad *1.21 *1.60 * precio_unitario;
END$$
DELIMITER ;

-- Creamos un trigger donde insertamos los datos facturados.
DELIMITER $$
CREATE TRIGGER insert_art_fact
AFTER INSERT ON factura
FOR EACH ROW
BEGIN
    INSERT INTO art_facturados (id_factura, id_codigo, id_descripcion, cantidad, id_precio)
    VALUES (NEW.id_factura, NEW.id_codigo,(
        SELECT id_descripcion 
        FROM productos 
        WHERE id_codigo = NEW.id_codigo
        ), 
    NEW.cantidad, NEW.id_precio
    );
END$$

DELIMITER ;

-- STORE PROCEDURE

-- CREAMOS UN STORE PROCEDURE DONDE AÑADIMOS PROVEEDORES A LA TABLA
-- Colocamos los datos necesarios para poder crear un nuevo proveedor, y luego se guarda la ejecucion.
-- Los datos no tienen que existir en la tabla para poder hacer la insercion.
start transaction;

delimiter $$
CREATE PROCEDURE Addproveedr(id int, proveed char(12), cuit char(30))
begin
	update proveedores
    set razon_social = proveed
    where id_prov = id;
    
    insert into proveedores values(id, proveed, cuit, domicilio);
    
    #APLICAMOS EL SAVEPOINT PARA GUARDAR LA ACTUALIZACION
    
    savepoint add_proveed;
    
end$$

delimiter ;;

commit;

DELIMITER //

create procedure AddProducto(IN codigo char(16), IN descripcion char(32), IN descripcion_adicional char(10)
)
BEGIN
    DECLARE save_codig char(20);
    
    START TRANSACTION;
    
    SAVEPOINT before_insert;
    
    INSERT INTO productos (id_codigo, id_descripcion, descripcion_adicional)
    VALUES (codigo, descripcion, descripcion_adicional);
    
    SET save_codig = CONCAT('savepoint_', codigo);
    SAVEPOINT save_codig;
    
    COMMIT;
END;

//

DELIMITER ;


