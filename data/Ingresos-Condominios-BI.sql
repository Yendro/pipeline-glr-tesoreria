WITH Ingresos_Condominios_BI AS (
    WITH ingresos AS (
        SELECT
            id_venta,
            INITCAP(EstatusIngreso) AS EstatusIngreso,
            NombreCondominio,
            Etapa,
            Unidad,
            TRIM(CONCAT(
                ARRAY_TO_STRING(ARRAY(SELECT INITCAP(word) FROM UNNEST(SPLIT(TRIM(NombreCliente), ' ')) AS word), ' '), ' ',
                ARRAY_TO_STRING(ARRAY(SELECT INITCAP(word) FROM UNNEST(SPLIT(TRIM(REPLACE(REPLACE(ApellidoPaternoCliente, '-', ''), '.', '')), ' ')) AS word), ' '), ' ',
                ARRAY_TO_STRING(ARRAY(SELECT INITCAP(word) FROM UNNEST(SPLIT(TRIM(REPLACE(REPLACE(ApellidoMaternoCliente, '-', ''), '.', '')), ' ')) AS word), ' ')))
            AS NombreCompletoCliente,
            id_ingreso,
            DATE(FechaIngreso) AS FechaIngreso,
            TRIM(CONCAT(
                ARRAY_TO_STRING(ARRAY(SELECT INITCAP(word) FROM UNNEST(SPLIT(TRIM(NombreUsuario), ' ')) AS word), ' '), ' ',
                ARRAY_TO_STRING(ARRAY(SELECT INITCAP(word) FROM UNNEST(SPLIT(TRIM(REPLACE(REPLACE(ApellidoPaternoUsuario, '-', ''), '.', '')), ' ')) AS word), ' '), ' ',
                ARRAY_TO_STRING(ARRAY(SELECT INITCAP(word) FROM UNNEST(SPLIT(TRIM(REPLACE(REPLACE(ApellidoMaternoUsuario, '-', ''), '.', '')), ' ')) AS word), ' ')))
            AS UsuarioRegistro,
            Banco,
            CONCAT ("STP_", BeneficiarioSTP) AS BeneficiarioSTP,
            Folio,
            FormaPago,
            CAST(Monto AS FLOAT64) AS Monto,
            CAST(
                CASE  
                    WHEN MontoCuota IS NULL AND MontoReserva IS NULL AND MontoFondo IS NULL THEN 0
                    ELSE COALESCE(MontoCuota, 0)
                END AS FLOAT64
            ) AS MontoCuota,
            CAST(
                CASE 
                    WHEN MontoCuota IS NULL AND MontoReserva IS NULL AND MontoFondo IS NULL THEN 0
                    ELSE COALESCE(MontoReserva, 0)
                END AS FLOAT64
            ) AS MontoReserva,
            CAST(
                CASE 
                    WHEN MontoCuota IS NULL AND MontoReserva IS NULL AND MontoFondo IS NULL THEN 0
                    ELSE COALESCE(MontoFondo, 0)
                END AS FLOAT64
            ) AS MontoFondo,
            CAST(SaldoPendientePorAplicar AS FLOAT64) AS SaldoPendientePorAplicar,
            -- FONDOS FUTUROS (SIN ESTADOS DE CUENTA)
            CAST(    
                CASE
                    WHEN MontoCuota IS NULL AND MontoReserva IS NULL AND MontoFondo IS NULL THEN Monto
                    ELSE 0
                END AS FLOAT64
            ) AS FondosFuturos,
        FROM EXTERNAL_QUERY("terraviva-439415.us.Condo", """
            SELECT
                i.id_ingreso,
                i.id_cliente,
                i.id_usuario,
                i.id_forma_pago,
                i.id_banco,
                i.folio AS Folio,
                i.monto AS Monto,
                NULLIF(i.fecha_ingreso, '0000-00-00') AS FechaIngreso,
                NULLIF(i.fecha_cancelacion, '0000-00-00') AS FechaCancelacion,
                b.nombre_banco AS Banco,
                fp.nombre AS FormaPago,
                stp.cuentaBeneficiario AS BeneficiarioSTP,
                fis.SALDOPENDIENTE_POR_APLICAR AS SaldoPendientePorAplicar,
                fis.STATUS AS EstatusIngreso,
                c.id_propiedad AS id_venta,
                c.NombreCliente,
                c.ApellidoPaternoCliente,
                c.ApellidoMaternoCliente,
                p.Etapa,
                p.Unidad,
                condo.NombreCondominio,
                fid.MontoCuota,
                fid.MontoReserva,
                fid.MontoFondo,
                u.NombreUsuario,
                u.ApellidoPaternoUsuario,
                u.ApellidoMaternoUsuario
            FROM ingreso AS i
            LEFT JOIN banco AS b ON i.id_banco = b.id_banco
            LEFT JOIN forma_pago AS fp ON i.id_forma_pago = fp.id_forma_pago
            LEFT JOIN stp_bitacora AS stp ON i.id_ingreso = stp.id_ingreso
            LEFT JOIN flujo_ingresos_sh AS fis ON i.id_ingreso = fis.IDINGRESO
            LEFT JOIN (
                SELECT
                    id_ingreso_dt,
                    MONTO_CUOTA AS MontoCuota,
                    MONTO_RESERVA AS MontoReserva,
                    MONTO_FONDO AS MontoFondo
                FROM flujo_ingresos_detallado_sh
            ) AS fid ON i.id_ingreso = fid.id_ingreso_dt
            LEFT JOIN (
                SELECT
                    id_usuario,
                    nombre AS NombreUsuario,
                    apellido_paterno AS ApellidoPaternoUsuario,
                    apellido_materno AS ApellidoMaternoUsuario
                FROM usuario
            ) AS u ON i.id_usuario = u.id_usuario
            LEFT JOIN (
                SELECT
                    id_cliente,
                    id_propiedad,
                    nombre AS NombreCliente,
                    apellido_p AS ApellidoPaternoCliente,
                    apellido_m AS ApellidoMaternoCliente
                FROM cliente
            ) AS c ON i.id_cliente = c.id_cliente
            LEFT JOIN (
                SELECT
                    id_propiedad,
                    id_condominio,
                    etapa AS Etapa,
                    num_unidad AS Unidad
                FROM propiedades
            ) AS p ON c.id_propiedad = p.id_propiedad
            LEFT JOIN (
                SELECT
                    id_condominio,
                    nombre_condominio AS NombreCondominio
                FROM condominio
            ) AS condo ON p.id_condominio = condo.id_condominio
        """)
    )
    SELECT 
        i.id_venta,
        i.EstatusIngreso,
        nd.Marca,
        nd.Desarrollo,
        nd.Privada,
        i.Etapa,
        i.Unidad,
        i.NombreCompletoCliente,
        i.id_ingreso,
        DATE(i.FechaIngreso) AS FechaIngreso,
        i.UsuarioRegistro,
        i.Banco,
        i.BeneficiarioSTP,
        i.Folio,
        i.FormaPago,
        i.Monto,
        i.MontoCuota,
        i.MontoReserva,
        i.MontoFondo,
        i.SaldoPendientePorAplicar,
        i.FondosFuturos
    FROM ingresos AS i
    LEFT JOIN `Dimensiones.NombreDesarrollo` AS nd ON i.NombreCondominio = nd.id_nombre_desarrollo
)
SELECT * FROM Ingresos_Condominios_BI
WHERE Desarrollo IS NOT NULL
    AND Desarrollo != 'Demo'
    AND UsuarioRegistro != 'Super Bq Administrador Manivela'
    AND FormaPago IS NOT NULL
    AND NOT (Desarrollo = 'San Eduardo' AND Privada = 'P5')
    AND Banco NOT IN ('GLR', 'REDONDEO')
    AND EXTRACT (YEAR FROM DATE(FechaIngreso)) = EXTRACT(YEAR FROM CURRENT_DATE())
    AND EXTRACT (MONTH FROM DATE(FechaIngreso))= EXTRACT(MONTH FROM CURRENT_DATE())