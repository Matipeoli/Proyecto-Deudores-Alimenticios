--
-- PostgreSQL database dump
--

\restrict cvkEyAmXDzoyEKKBaWDPbvJyNdqL29dCYh1zMgsqXNqvD9Gg3H7NZZO3aM5FB1y

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

-- Started on 2026-03-06 19:46:45
CREATE ROLE portal_app;
CREATE ROLE portal_readonly;

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 8 (class 2615 OID 17490)
-- Name: portal; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA portal;


ALTER SCHEMA portal OWNER TO postgres;

--
-- TOC entry 951 (class 1247 OID 17604)
-- Name: accion_auditoria_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.accion_auditoria_t AS ENUM (
    'crear',
    'actualizar',
    'eliminar',
    'aprobar',
    'rechazar',
    'reasignar',
    'login',
    'logout'
);


ALTER TYPE portal.accion_auditoria_t OWNER TO postgres;

--
-- TOC entry 945 (class 1247 OID 17588)
-- Name: estado_deuda_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.estado_deuda_t AS ENUM (
    'vigente',
    'prescrita'
);


ALTER TYPE portal.estado_deuda_t OWNER TO postgres;

--
-- TOC entry 933 (class 1247 OID 17546)
-- Name: estado_empleado_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.estado_empleado_t AS ENUM (
    'activo',
    'inactivo'
);


ALTER TYPE portal.estado_empleado_t OWNER TO postgres;

--
-- TOC entry 936 (class 1247 OID 17552)
-- Name: estado_solicitud_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.estado_solicitud_t AS ENUM (
    'iniciada',
    'pendiente_pago',
    'pago_fallido',
    'pagada',
    'en_revision',
    'aprobada',
    'rechazada',
    'cancelada',
    'certificado_emitido'
);


ALTER TYPE portal.estado_solicitud_t OWNER TO postgres;

--
-- TOC entry 942 (class 1247 OID 17578)
-- Name: estado_transaccion_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.estado_transaccion_t AS ENUM (
    'pendiente',
    'exitoso',
    'fallido',
    'reembolsado'
);


ALTER TYPE portal.estado_transaccion_t OWNER TO postgres;

--
-- TOC entry 939 (class 1247 OID 17572)
-- Name: prioridad_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.prioridad_t AS ENUM (
    'normal',
    'urgente'
);


ALTER TYPE portal.prioridad_t OWNER TO postgres;

--
-- TOC entry 930 (class 1247 OID 17541)
-- Name: rol_empleado_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.rol_empleado_t AS ENUM (
    'empleado',
    'administrador'
);


ALTER TYPE portal.rol_empleado_t OWNER TO postgres;

--
-- TOC entry 948 (class 1247 OID 17594)
-- Name: tipo_config_t; Type: TYPE; Schema: portal; Owner: postgres
--

CREATE TYPE portal.tipo_config_t AS ENUM (
    'texto',
    'numero',
    'booleano',
    'json'
);


ALTER TYPE portal.tipo_config_t OWNER TO postgres;

--
-- TOC entry 304 (class 1255 OID 17627)
-- Name: fn_generar_numero_certificado(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_generar_numero_certificado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.numero_certificado IS NULL OR NEW.numero_certificado = '' THEN
        NEW.numero_certificado :=
            'CERTIF-' ||
            TO_CHAR(NOW(), 'YYYY') || '-' ||
            LPAD(NEXTVAL('portal.seq_numero_certificado')::TEXT, 8, '0');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION portal.fn_generar_numero_certificado() OWNER TO postgres;

--
-- TOC entry 302 (class 1255 OID 17624)
-- Name: fn_generar_numero_solicitud(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_generar_numero_solicitud() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.numero_solicitud IS NULL OR NEW.numero_solicitud = '' THEN
        NEW.numero_solicitud :=
            'CERT-' ||
            TO_CHAR(NOW(), 'YYYY') || '-' ||
            LPAD(NEXTVAL('portal.solicitudes_id_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION portal.fn_generar_numero_solicitud() OWNER TO postgres;

--
-- TOC entry 300 (class 1255 OID 17622)
-- Name: fn_prevent_auditoria_mod(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_prevent_auditoria_mod() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        'La tabla auditoria es inmutable. Operación % no permitida. '
        'Registro id=% no puede ser modificado.',
        TG_OP,
        OLD.id;
END;
$$;


ALTER FUNCTION portal.fn_prevent_auditoria_mod() OWNER TO postgres;

--
-- TOC entry 301 (class 1255 OID 17623)
-- Name: fn_registrar_auditoria(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_registrar_auditoria() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_accion            portal.accion_auditoria_t;
    v_valores_anteriores JSONB;
    v_valores_nuevos    JSONB;
    v_usuario_id        INTEGER;
    v_usuario_email     VARCHAR(255);
    v_usuario_rol       VARCHAR(50);
    v_ip                INET;
    v_session_id        VARCHAR(255);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_accion             := 'crear';
        v_valores_anteriores := NULL;
        v_valores_nuevos     := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        v_accion             := 'actualizar';
        v_valores_anteriores := to_jsonb(OLD);
        v_valores_nuevos     := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        v_accion             := 'eliminar';
        v_valores_anteriores := to_jsonb(OLD);
        v_valores_nuevos     := NULL;
    END IF;

    v_usuario_id    := NULLIF(current_setting('app.current_user_id',    TRUE), '')::INTEGER;
    v_usuario_email := NULLIF(current_setting('app.current_user_email', TRUE), '');
    v_usuario_rol   := NULLIF(current_setting('app.current_user_rol',   TRUE), '');
    v_ip            := NULLIF(current_setting('app.current_ip',         TRUE), '')::INET;
    v_session_id    := NULLIF(current_setting('app.current_session_id', TRUE), '');

    INSERT INTO portal.auditoria (
        tabla_afectada,
        registro_id,
        accion,
        usuario_id,
        usuario_email,
        usuario_rol,
        valores_anteriores,
        valores_nuevos,
        ip_address,
        session_id
    ) VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        v_accion,
        v_usuario_id,
        v_usuario_email,
        v_usuario_rol,
        v_valores_anteriores,
        v_valores_nuevos,
        v_ip,
        v_session_id
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION portal.fn_registrar_auditoria() OWNER TO postgres;

--
-- TOC entry 308 (class 1255 OID 17907)
-- Name: fn_set_fecha_actualizacion(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_set_fecha_actualizacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_actualizacion = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION portal.fn_set_fecha_actualizacion() OWNER TO postgres;

--
-- TOC entry 299 (class 1255 OID 17621)
-- Name: fn_set_updated_at(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION portal.fn_set_updated_at() OWNER TO postgres;

--
-- TOC entry 303 (class 1255 OID 17625)
-- Name: fn_solicitud_timestamps_estado(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.fn_solicitud_timestamps_estado() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.estado = 'en_revision' AND OLD.estado <> 'en_revision' THEN
        NEW.fecha_revision = NOW();
    END IF;
    IF NEW.estado = 'certificado_emitido' AND OLD.estado <> 'certificado_emitido' THEN
        NEW.fecha_emision = NOW();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION portal.fn_solicitud_timestamps_estado() OWNER TO postgres;

--
-- TOC entry 307 (class 1255 OID 17902)
-- Name: limpiar_otp_expirados(); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.limpiar_otp_expirados() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_filas_eliminadas INTEGER := 0;
BEGIN
    DELETE FROM portal.otp_sessions
    WHERE expira_at < NOW() - INTERVAL '1 hour';

    GET DIAGNOSTICS v_filas_eliminadas = ROW_COUNT;
    RETURN v_filas_eliminadas;
END;
$$;


ALTER FUNCTION portal.limpiar_otp_expirados() OWNER TO postgres;

--
-- TOC entry 306 (class 1255 OID 17901)
-- Name: limpiar_solicitudes_antiguas(integer); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.limpiar_solicitudes_antiguas(p_dias_antiguedad integer DEFAULT 365) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_filas_eliminadas INTEGER := 0;
BEGIN
    DELETE FROM portal.solicitudes
    WHERE estado IN ('cancelada', 'rechazada')
      AND updated_at < (NOW() - (p_dias_antiguedad || ' days')::INTERVAL);

    GET DIAGNOSTICS v_filas_eliminadas = ROW_COUNT;

    INSERT INTO portal.auditoria (
        tabla_afectada, registro_id, accion,
        valores_nuevos
    ) VALUES (
        'solicitudes', 0, 'eliminar',
        jsonb_build_object(
            'operacion', 'limpieza_automatica',
            'dias_antiguedad', p_dias_antiguedad,
            'filas_eliminadas', v_filas_eliminadas,
            'ejecutado_at', NOW()
        )
    );

    RETURN v_filas_eliminadas;
END;
$$;


ALTER FUNCTION portal.limpiar_solicitudes_antiguas(p_dias_antiguedad integer) OWNER TO postgres;

--
-- TOC entry 305 (class 1255 OID 17900)
-- Name: obtener_estadisticas_empleado(integer); Type: FUNCTION; Schema: portal; Owner: postgres
--

CREATE FUNCTION portal.obtener_estadisticas_empleado(p_empleado_id integer) RETURNS TABLE(total_asignadas bigint, aprobadas bigint, rechazadas bigint, en_proceso bigint, tiempo_promedio_horas numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)                                                            AS total_asignadas,
        COUNT(*) FILTER (WHERE estado = 'certificado_emitido')             AS aprobadas,
        COUNT(*) FILTER (WHERE estado = 'rechazada')                       AS rechazadas,
        COUNT(*) FILTER (WHERE estado IN ('pagada', 'en_revision'))        AS en_proceso,
        ROUND(
            AVG(
                EXTRACT(EPOCH FROM (fecha_emision - fecha_pago)) / 3600.0
            ) FILTER (
                WHERE fecha_emision IS NOT NULL AND fecha_pago IS NOT NULL
            ),
            2
        )                                                                   AS tiempo_promedio_horas
    FROM portal.solicitudes
    WHERE empleado_asignado_id = p_empleado_id;
END;
$$;


ALTER FUNCTION portal.obtener_estadisticas_empleado(p_empleado_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 234 (class 1259 OID 17781)
-- Name: auditoria; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.auditoria (
    id integer NOT NULL,
    tabla_afectada character varying(100) NOT NULL,
    registro_id integer NOT NULL,
    accion portal.accion_auditoria_t NOT NULL,
    usuario_id integer,
    usuario_email character varying(255),
    usuario_rol character varying(50),
    valores_anteriores jsonb,
    valores_nuevos jsonb,
    ip_address inet,
    user_agent text,
    session_id character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE portal.auditoria OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 17780)
-- Name: auditoria_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.auditoria ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 17743)
-- Name: certificados; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.certificados (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    empleado_emisor_id integer,
    numero_certificado character varying(100) NOT NULL,
    archivo_pdf_path text NOT NULL,
    archivo_pdf_hash character varying(255) NOT NULL,
    fecha_emision date DEFAULT CURRENT_DATE NOT NULL,
    fecha_vencimiento date GENERATED ALWAYS AS ((fecha_emision + '90 days'::interval)) STORED NOT NULL,
    firma_digital text,
    es_deudor boolean DEFAULT false NOT NULL,
    monto_deuda numeric(15,2),
    tipo_deuda character varying(100),
    estado_deuda portal.estado_deuda_t,
    numero_expediente character varying(100),
    fecha_deuda date,
    tamano_bytes integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_certificados_tamano CHECK (((tamano_bytes IS NULL) OR ((tamano_bytes > 0) AND (tamano_bytes <= 5242880)))),
    CONSTRAINT chk_certificados_vigencia CHECK ((fecha_vencimiento > fecha_emision))
);


ALTER TABLE portal.certificados OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 17742)
-- Name: certificados_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.certificados ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.certificados_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 17629)
-- Name: ciudades; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.ciudades (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    provincia character varying(100) DEFAULT 'Santa Fe'::character varying NOT NULL,
    estado character varying(20) DEFAULT 'activa'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ciudades_estado_check CHECK (((estado)::text = ANY ((ARRAY['activa'::character varying, 'inactiva'::character varying])::text[])))
);


ALTER TABLE portal.ciudades OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17628)
-- Name: ciudades_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.ciudades ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.ciudades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 17800)
-- Name: configuracion; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.configuracion (
    id integer NOT NULL,
    clave character varying(100) NOT NULL,
    valor text NOT NULL,
    tipo portal.tipo_config_t DEFAULT 'texto'::portal.tipo_config_t NOT NULL,
    descripcion text,
    updated_by integer,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE portal.configuracion OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 17799)
-- Name: configuracion_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.configuracion ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.configuracion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 17648)
-- Name: empleados; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.empleados (
    id integer NOT NULL,
    nombre character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    estado portal.estado_empleado_t DEFAULT 'activo'::portal.estado_empleado_t NOT NULL,
    rol portal.rol_empleado_t DEFAULT 'empleado'::portal.rol_empleado_t NOT NULL,
    ciudad_id integer,
    fecha_creacion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT now() NOT NULL,
    ultimo_acceso timestamp with time zone,
    CONSTRAINT chk_empleados_email_institucional CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@gobierno\.gob\.ar$'::text)),
    CONSTRAINT chk_empleados_nombre_len CHECK ((length(TRIM(BOTH FROM nombre)) >= 3))
);


ALTER TABLE portal.empleados OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17647)
-- Name: empleados_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.empleados ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.empleados_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 238 (class 1259 OID 17824)
-- Name: otp_sessions; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.otp_sessions (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    cuit_dni character varying(20) NOT NULL,
    codigo_otp_hash character varying(255) NOT NULL,
    intentos smallint DEFAULT 0 NOT NULL,
    expira_at timestamp with time zone NOT NULL,
    usado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_otp_cuit_dni CHECK ((((cuit_dni)::text ~ '^\d{2}-\d{7,8}-\d$'::text) OR ((cuit_dni)::text ~ '^\d{7,8}$'::text))),
    CONSTRAINT chk_otp_expira CHECK ((expira_at > created_at)),
    CONSTRAINT chk_otp_intentos CHECK (((intentos >= 0) AND (intentos <= 3)))
);


ALTER TABLE portal.otp_sessions OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 17823)
-- Name: otp_sessions_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.otp_sessions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.otp_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 222 (class 1259 OID 17626)
-- Name: seq_numero_certificado; Type: SEQUENCE; Schema: portal; Owner: postgres
--

CREATE SEQUENCE portal.seq_numero_certificado
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE portal.seq_numero_certificado OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17677)
-- Name: solicitudes; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.solicitudes (
    id integer NOT NULL,
    numero_solicitud character varying(50) NOT NULL,
    nombre_completo character varying(255) NOT NULL,
    cuit_dni character varying(20) NOT NULL,
    email character varying(255) NOT NULL,
    ciudad_id integer NOT NULL,
    estado portal.estado_solicitud_t DEFAULT 'iniciada'::portal.estado_solicitud_t NOT NULL,
    prioridad portal.prioridad_t DEFAULT 'normal'::portal.prioridad_t NOT NULL,
    empleado_asignado_id integer,
    observaciones text,
    motivo_rechazo text,
    fecha_solicitud timestamp with time zone DEFAULT now() NOT NULL,
    fecha_pago timestamp with time zone,
    fecha_revision timestamp with time zone,
    fecha_emision timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_solicitudes_cuit_dni CHECK ((((cuit_dni)::text ~ '^\d{2}-\d{7,8}-\d$'::text) OR ((cuit_dni)::text ~ '^\d{7,8}$'::text))),
    CONSTRAINT chk_solicitudes_email CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT chk_solicitudes_rechazo_requiere_motivo CHECK (((estado <> 'rechazada'::portal.estado_solicitud_t) OR ((motivo_rechazo IS NOT NULL) AND (length(TRIM(BOTH FROM motivo_rechazo)) >= 10))))
);


ALTER TABLE portal.solicitudes OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17676)
-- Name: solicitudes_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.solicitudes ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.solicitudes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 17716)
-- Name: transacciones; Type: TABLE; Schema: portal; Owner: postgres
--

CREATE TABLE portal.transacciones (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    monto numeric(10,2) NOT NULL,
    estado portal.estado_transaccion_t DEFAULT 'pendiente'::portal.estado_transaccion_t NOT NULL,
    metodo_pago character varying(50),
    referencia_pluspagos character varying(255),
    codigo_autorizacion character varying(100),
    mensaje_error text,
    fecha_transaccion timestamp with time zone DEFAULT now() NOT NULL,
    fecha_confirmacion timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_transacciones_exitoso_requiere_codigo CHECK (((estado <> 'exitoso'::portal.estado_transaccion_t) OR (codigo_autorizacion IS NOT NULL))),
    CONSTRAINT chk_transacciones_fallido_requiere_mensaje CHECK (((estado <> 'fallido'::portal.estado_transaccion_t) OR (mensaje_error IS NOT NULL))),
    CONSTRAINT chk_transacciones_monto CHECK ((monto > (0)::numeric))
);


ALTER TABLE portal.transacciones OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17715)
-- Name: transacciones_id_seq; Type: SEQUENCE; Schema: portal; Owner: postgres
--

ALTER TABLE portal.transacciones ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME portal.transacciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 240 (class 1259 OID 17895)
-- Name: v_kpis_dashboard; Type: VIEW; Schema: portal; Owner: postgres
--

CREATE VIEW portal.v_kpis_dashboard AS
 SELECT count(*) AS total_solicitudes,
    count(*) FILTER (WHERE (s.estado = 'certificado_emitido'::portal.estado_solicitud_t)) AS certificados_emitidos,
    count(*) FILTER (WHERE (s.estado = 'pendiente_pago'::portal.estado_solicitud_t)) AS pendientes_pago,
    count(*) FILTER (WHERE (s.estado = 'en_revision'::portal.estado_solicitud_t)) AS en_revision,
    count(*) FILTER (WHERE (s.estado = 'rechazada'::portal.estado_solicitud_t)) AS rechazadas,
    count(*) FILTER (WHERE (s.estado = 'pagada'::portal.estado_solicitud_t)) AS pagadas,
    COALESCE(sum(t.monto) FILTER (WHERE (t.estado = 'exitoso'::portal.estado_transaccion_t)), (0)::numeric) AS ingresos_totales,
    round((((count(*) FILTER (WHERE (s.estado = 'certificado_emitido'::portal.estado_solicitud_t)))::numeric / (NULLIF(count(*) FILTER (WHERE (s.estado = ANY (ARRAY['certificado_emitido'::portal.estado_solicitud_t, 'rechazada'::portal.estado_solicitud_t]))), 0))::numeric) * (100)::numeric), 2) AS tasa_aprobacion
   FROM (portal.solicitudes s
     LEFT JOIN LATERAL ( SELECT tr.monto,
            tr.estado
           FROM portal.transacciones tr
          WHERE ((tr.solicitud_id = s.id) AND (tr.estado = 'exitoso'::portal.estado_transaccion_t))
         LIMIT 1) t ON (true));


ALTER VIEW portal.v_kpis_dashboard OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 17890)
-- Name: v_solicitudes_completas; Type: VIEW; Schema: portal; Owner: postgres
--

CREATE VIEW portal.v_solicitudes_completas AS
 SELECT s.id,
    s.numero_solicitud,
    s.nombre_completo,
    s.cuit_dni,
    s.email,
    s.estado,
    s.prioridad,
    s.observaciones,
    s.motivo_rechazo,
    s.fecha_solicitud,
    s.fecha_pago,
    s.fecha_revision,
    s.fecha_emision,
    s.created_at,
    s.updated_at,
    e.nombre AS empleado_asignado_nombre,
    e.email AS empleado_asignado_email,
    t.id AS transaccion_id,
    t.monto AS monto_pagado,
    t.estado AS estado_pago,
    t.metodo_pago,
    t.referencia_pluspagos,
    t.codigo_autorizacion,
    t.fecha_confirmacion,
    c.id AS certificado_id,
    c.numero_certificado,
    c.archivo_pdf_path,
    c.fecha_emision AS certificado_fecha_emision,
    c.fecha_vencimiento,
    c.es_deudor
   FROM (((portal.solicitudes s
     LEFT JOIN portal.empleados e ON ((s.empleado_asignado_id = e.id)))
     LEFT JOIN LATERAL ( SELECT tr.id,
            tr.solicitud_id,
            tr.monto,
            tr.estado,
            tr.metodo_pago,
            tr.referencia_pluspagos,
            tr.codigo_autorizacion,
            tr.mensaje_error,
            tr.fecha_transaccion,
            tr.fecha_confirmacion,
            tr.created_at
           FROM portal.transacciones tr
          WHERE (tr.solicitud_id = s.id)
          ORDER BY tr.fecha_transaccion DESC
         LIMIT 1) t ON (true))
     LEFT JOIN portal.certificados c ON ((s.id = c.solicitud_id)));


ALTER VIEW portal.v_solicitudes_completas OWNER TO postgres;

--
-- TOC entry 5169 (class 0 OID 17781)
-- Dependencies: 234
-- Data for Name: auditoria; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.auditoria (id, tabla_afectada, registro_id, accion, usuario_id, usuario_email, usuario_rol, valores_anteriores, valores_nuevos, ip_address, user_agent, session_id, created_at) FROM stdin;
1	empleados	1	crear	\N	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T12:44:53.332707-03:00"}	\N	\N	\N	2026-02-26 12:44:53.332707-03
2	empleados	2	crear	\N	\N	\N	\N	{"id": 2, "rol": "empleado", "email": "empleado@gobierno.gob.ar", "estado": "activo", "nombre": "María López", "ciudad_id": 1, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T12:44:53.332707-03:00"}	\N	\N	\N	2026-02-26 12:44:53.332707-03
3	empleados	3	crear	\N	\N	\N	\N	{"id": 3, "rol": "empleado", "email": "ana.martinez@gobierno.gob.ar", "estado": "activo", "nombre": "Ana Martínez", "ciudad_id": 3, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T12:44:53.332707-03:00"}	\N	\N	\N	2026-02-26 12:44:53.332707-03
4	empleados	4	crear	\N	\N	\N	\N	{"id": 4, "rol": "empleado", "email": "roberto.silva@gobierno.gob.ar", "estado": "activo", "nombre": "Roberto Silva", "ciudad_id": 4, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T12:44:53.332707-03:00"}	\N	\N	\N	2026-02-26 12:44:53.332707-03
5	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T12:44:53.332707-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T15:58:10.148867-03:00"}	\N	\N	\N	2026-02-26 15:58:10.148867-03
6	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T15:58:10.148867-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-26T16:01:15.719571-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T16:01:15.719571-03:00"}	\N	\N	\N	2026-02-26 16:01:15.719571-03
7	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-26 16:01:15.748182-03
8	solicitudes	1	crear	\N	\N	\N	\N	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T19:54:23.38444-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 19:54:23.38444-03
9	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-26T16:01:15.719571-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T16:01:15.719571-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-26T20:03:29.956658-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T20:03:29.956658-03:00"}	\N	\N	\N	2026-02-26 20:03:29.956658-03
10	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-26 20:03:30.020596-03
11	solicitudes	1	actualizar	\N	\N	\N	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T19:54:23.38444-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T20:07:32.179285-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 20:07:32.179285-03
12	solicitudes	1	actualizar	\N	\N	\N	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T20:07:32.179285-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T20:14:22.585203-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 20:14:22.585203-03
13	certificados	1	crear	\N	\N	\N	\N	{"id": 1, "es_deudor": false, "created_at": "2026-02-26T20:17:14.943762-03:00", "tipo_deuda": null, "fecha_deuda": null, "monto_deuda": null, "estado_deuda": null, "solicitud_id": 1, "tamano_bytes": 706822, "fecha_emision": "2026-02-26", "firma_digital": null, "archivo_pdf_hash": "16ec95bd673a70a3f2204de7abc2104b76eb0f8543cf34871e1334293e711115", "archivo_pdf_path": "certificados/1772147834325-454169614.pdf", "fecha_vencimiento": "2026-05-27", "numero_expediente": null, "empleado_emisor_id": 1, "numero_certificado": "CERTIF-2026-00000001"}	\N	\N	\N	2026-02-26 20:17:14.943762-03
75	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:34:36.675702-03
14	solicitudes	1	actualizar	\N	\N	\N	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T20:14:22.585203-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	{"id": 1, "email": "mo1844pedro@gmail.com", "estado": "certificado_emitido", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T19:54:23.38444-03:00", "fecha_pago": null, "updated_at": "2026-02-26T20:17:15.049951-03:00", "fecha_emision": "2026-02-26T20:17:15.049951-03:00", "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T19:54:23.38444-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000002", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 20:17:15.049951-03
15	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-26T20:03:29.956658-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T20:03:29.956658-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-26T21:49:08.753571-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T21:49:08.753571-03:00"}	\N	\N	\N	2026-02-26 21:49:08.753571-03
16	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-26 21:49:08.935229-03
17	solicitudes	3	crear	\N	\N	\N	\N	{"id": 3, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T22:10:50.490346-03:00", "fecha_pago": null, "updated_at": "2026-02-26T22:10:50.490346-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T22:10:50.490346-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000004", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 22:10:50.490346-03
18	solicitudes	5	crear	\N	\N	\N	\N	{"id": 5, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T22:16:47.421498-03:00", "fecha_pago": null, "updated_at": "2026-02-26T22:16:47.421498-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T22:16:47.421498-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000006", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 22:16:47.421498-03
19	solicitudes	7	crear	\N	\N	\N	\N	{"id": 7, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T22:24:22.023627-03:00", "fecha_pago": null, "updated_at": "2026-02-26T22:24:22.023627-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T22:24:22.023627-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000008", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 22:24:22.023627-03
20	solicitudes	9	crear	\N	\N	\N	\N	{"id": 9, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T22:24:47.203091-03:00", "fecha_pago": null, "updated_at": "2026-02-26T22:24:47.203091-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T22:24:47.203091-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000010", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 22:24:47.203091-03
21	solicitudes	11	crear	\N	\N	\N	\N	{"id": 11, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-26T22:27:22.180888-03:00", "fecha_pago": null, "updated_at": "2026-02-26T22:27:22.180888-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-26T22:27:22.180888-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000012", "empleado_asignado_id": null}	\N	\N	\N	2026-02-26 22:27:22.180888-03
22	solicitudes	13	crear	\N	\N	\N	\N	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": null, "updated_at": "2026-02-27T10:52:32.66158-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	\N	\N	\N	2026-02-27 10:52:32.66158-03
23	solicitudes	13	actualizar	\N	\N	\N	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": null, "updated_at": "2026-02-27T10:52:32.66158-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-02-27T10:55:01.65192-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	\N	\N	\N	2026-02-27 10:55:01.65192-03
24	solicitudes	15	crear	\N	\N	\N	\N	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": null, "updated_at": "2026-02-27T13:56:05.231204-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	\N	\N	\N	2026-02-27 13:56:05.231204-03
113	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 14:12:01.861914-03
25	solicitudes	15	actualizar	\N	\N	\N	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": null, "updated_at": "2026-02-27T13:56:05.231204-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": "2026-02-27T13:59:56.988481-03:00", "updated_at": "2026-02-27T13:59:56.988481-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	\N	\N	\N	2026-02-27 13:59:56.988481-03
26	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-26T21:49:08.753571-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T21:49:08.753571-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-27T15:04:49.541997-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T15:04:49.541997-03:00"}	\N	\N	\N	2026-02-27 15:04:49.541997-03
27	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-27 15:04:49.607988-03
28	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-27T15:04:49.541997-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T15:04:49.541997-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-27T15:35:48.725969-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T15:35:48.725969-03:00"}	\N	\N	\N	2026-02-27 15:35:48.725969-03
29	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-27 15:35:48.78736-03
30	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$WjQwE.pxXDgw3Ui3CJwwR.YL2AcT32AoCJHdR1l6B.bs1ANXq.nJW", "ultimo_acceso": "2026-02-27T15:35:48.725969-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T15:35:48.725969-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-02-27T15:35:48.725969-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T15:43:28.297834-03:00"}	\N	\N	\N	2026-02-27 15:43:28.297834-03
31	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-02-27T15:35:48.725969-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T15:43:28.297834-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-02-27T18:27:36.0818-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T18:27:36.0818-03:00"}	\N	\N	\N	2026-02-27 18:27:36.0818-03
32	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-27 18:27:36.225276-03
33	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-02-27T18:27:36.0818-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T18:27:36.0818-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-02-27T18:55:56.986888-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T18:55:56.986888-03:00"}	\N	\N	\N	2026-02-27 18:55:56.986888-03
34	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-02-27 18:55:57.034331-03
35	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-02-27T18:55:56.986888-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-27T18:55:56.986888-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-01T17:16:04.700178-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-01T17:16:04.700178-03:00"}	\N	\N	\N	2026-03-01 17:16:04.700178-03
36	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-01 17:16:04.81821-03
37	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-01T17:16:04.700178-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-01T17:16:04.700178-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-03T16:23:18.154895-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-03T16:23:18.154895-03:00"}	\N	\N	\N	2026-03-03 16:23:18.154895-03
38	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-03 16:23:18.320939-03
39	solicitudes	13	actualizar	\N	\N	\N	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-02-27T10:55:01.65192-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-03-03T16:24:26.783128-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:24:26.783128-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	\N	\N	\N	2026-03-03 16:24:26.783128-03
40	solicitudes	13	actualizar	\N	\N	\N	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-03-03T16:24:26.783128-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:24:26.783128-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-03-03T16:24:35.953119-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:24:26.783128-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	\N	\N	\N	2026-03-03 16:24:35.953119-03
41	solicitudes	15	actualizar	\N	\N	\N	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": "2026-02-27T13:59:56.988481-03:00", "updated_at": "2026-02-27T13:59:56.988481-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": "2026-02-27T13:59:56.988481-03:00", "updated_at": "2026-03-03T16:25:44.850383-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:25:44.850383-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	\N	\N	\N	2026-03-03 16:25:44.850383-03
42	solicitudes	15	actualizar	\N	\N	\N	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": "2026-02-27T13:59:56.988481-03:00", "updated_at": "2026-03-03T16:25:44.850383-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:25:44.850383-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	{"id": 15, "email": "mo1844pedro@gmail.com", "estado": "rechazada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T13:56:05.231204-03:00", "fecha_pago": "2026-02-27T13:59:56.988481-03:00", "updated_at": "2026-03-03T16:27:08.012936-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:25:44.850383-03:00", "motivo_rechazo": "No se encuentra persona con ese CUIT/DNI y nombre", "fecha_solicitud": "2026-02-27T13:56:05.231204-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000016", "empleado_asignado_id": null}	\N	\N	\N	2026-03-03 16:27:08.012936-03
43	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-03T16:23:18.154895-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-03T16:23:18.154895-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-04T15:15:46.391958-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T15:15:46.391958-03:00"}	\N	\N	\N	2026-03-04 15:15:46.391958-03
44	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-04 15:15:46.529481-03
45	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-04T15:15:46.391958-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T15:15:46.391958-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-04T15:16:45.952881-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T15:16:45.952881-03:00"}	\N	\N	\N	2026-03-04 15:16:45.952881-03
46	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-04 15:16:45.982064-03
47	empleados	3	actualizar	\N	\N	\N	{"id": 3, "rol": "empleado", "email": "ana.martinez@gobierno.gob.ar", "estado": "activo", "nombre": "Ana Martínez", "ciudad_id": 3, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-02-26T12:44:53.332707-03:00"}	{"id": 3, "rol": "empleado", "email": "ana.martinez@gobierno.gob.ar", "estado": "inactivo", "nombre": "Ana Martínez", "ciudad_id": 3, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T18:58:39.109221-03:00"}	\N	\N	\N	2026-03-04 18:58:39.109221-03
48	empleados	3	actualizar	\N	\N	\N	{"id": 3, "rol": "empleado", "email": "ana.martinez@gobierno.gob.ar", "estado": "inactivo", "nombre": "Ana Martínez", "ciudad_id": 3, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T18:58:39.109221-03:00"}	{"id": 3, "rol": "empleado", "email": "ana.martinez@gobierno.gob.ar", "estado": "activo", "nombre": "Ana Martínez", "ciudad_id": 3, "password_hash": "$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR", "ultimo_acceso": null, "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T18:58:46.797571-03:00"}	\N	\N	\N	2026-03-04 18:58:46.797571-03
49	empleados	5	crear	\N	\N	\N	\N	{"id": 5, "rol": "empleado", "email": "matipe@gobierno.gob.ar", "estado": "activo", "nombre": "Matias Pedro", "ciudad_id": null, "password_hash": "$2b$12$VOqvaAW5GKrWoWp4GFv9c.rP1CNWNhVM7hrLQXbZQAdlTzxkJBHDq", "ultimo_acceso": null, "fecha_creacion": "2026-03-04T19:04:08.204435-03:00", "fecha_actualizacion": "2026-03-04T19:04:08.204435-03:00"}	\N	\N	\N	2026-03-04 19:04:08.204435-03
50	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-04 19:30:49.683626-03
51	solicitudes	17	crear	\N	\N	\N	\N	{"id": 17, "email": "matiaspeoliver@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T19:31:44.231235-03:00", "fecha_pago": null, "updated_at": "2026-03-04T19:31:44.231235-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T19:31:44.231235-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000018", "empleado_asignado_id": null}	\N	\N	\N	2026-03-04 19:31:44.231235-03
52	solicitudes	17	actualizar	\N	\N	\N	{"id": 17, "email": "matiaspeoliver@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T19:31:44.231235-03:00", "fecha_pago": null, "updated_at": "2026-03-04T19:31:44.231235-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T19:31:44.231235-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000018", "empleado_asignado_id": null}	{"id": 17, "email": "matiaspeoliver@gmail.com", "estado": "cancelada", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T19:31:44.231235-03:00", "fecha_pago": null, "updated_at": "2026-03-04T19:31:50.601395-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T19:31:44.231235-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000018", "empleado_asignado_id": null}	\N	\N	\N	2026-03-04 19:31:50.601395-03
53	solicitudes	19	crear	\N	\N	\N	\N	{"id": 19, "email": "matiaspeoliver@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T19:33:10.347764-03:00", "fecha_pago": null, "updated_at": "2026-03-04T19:33:10.347764-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T19:33:10.347764-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000020", "empleado_asignado_id": null}	\N	\N	\N	2026-03-04 19:33:10.347764-03
54	solicitudes	19	actualizar	\N	\N	\N	{"id": 19, "email": "matiaspeoliver@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T19:33:10.347764-03:00", "fecha_pago": null, "updated_at": "2026-03-04T19:33:10.347764-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T19:33:10.347764-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000020", "empleado_asignado_id": null}	{"id": 19, "email": "matiaspeoliver@gmail.com", "estado": "cancelada", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T19:33:10.347764-03:00", "fecha_pago": null, "updated_at": "2026-03-04T19:37:04.420512-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T19:33:10.347764-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000020", "empleado_asignado_id": null}	\N	\N	\N	2026-03-04 19:37:04.420512-03
55	solicitudes	21	crear	\N	\N	\N	\N	{"id": 21, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-04T23:58:51.964237-03:00", "fecha_pago": null, "updated_at": "2026-03-04T23:58:51.964237-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-04T23:58:51.964237-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000022", "empleado_asignado_id": null}	\N	\N	\N	2026-03-04 23:58:51.964237-03
56	solicitudes	23	crear	\N	\N	\N	\N	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": null, "updated_at": "2026-03-05T00:04:55.681943-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 00:04:55.681943-03
57	solicitudes	25	crear	\N	\N	\N	\N	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": null, "updated_at": "2026-03-05T00:08:02.510321-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 00:08:02.510321-03
58	solicitudes	25	actualizar	\N	\N	\N	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": null, "updated_at": "2026-03-05T00:08:02.510321-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": null}	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": "2026-03-05T00:08:37.855781-03:00", "updated_at": "2026-03-05T00:08:37.855781-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 00:08:37.855781-03
59	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-04T15:16:45.952881-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-04T15:16:45.952881-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T00:11:06.522248-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T00:11:06.522248-03:00"}	\N	\N	\N	2026-03-05 00:11:06.522248-03
60	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 00:11:06.57605-03
61	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T00:11:06.522248-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T00:11:06.522248-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:23:07.702944-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:23:07.702944-03:00"}	\N	\N	\N	2026-03-05 12:23:07.702944-03
62	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:23:07.808046-03
63	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:24:46.255862-03
64	solicitudes	27	crear	\N	\N	\N	\N	{"id": 27, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040209", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T12:29:36.449829-03:00", "fecha_pago": null, "updated_at": "2026-03-05T12:29:36.449829-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T12:29:36.449829-03:00", "nombre_completo": "Pedro Oliver", "numero_solicitud": "CERT-2026-000028", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 12:29:36.449829-03
65	solicitudes	27	actualizar	\N	\N	\N	{"id": 27, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040209", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T12:29:36.449829-03:00", "fecha_pago": null, "updated_at": "2026-03-05T12:29:36.449829-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T12:29:36.449829-03:00", "nombre_completo": "Pedro Oliver", "numero_solicitud": "CERT-2026-000028", "empleado_asignado_id": null}	{"id": 27, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "46040209", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T12:29:36.449829-03:00", "fecha_pago": "2026-03-05T12:30:03.288286-03:00", "updated_at": "2026-03-05T12:30:03.288286-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T12:29:36.449829-03:00", "nombre_completo": "Pedro Oliver", "numero_solicitud": "CERT-2026-000028", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 12:30:03.288286-03
66	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:23:07.702944-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:23:07.702944-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:31:22.691351-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:31:22.691351-03:00"}	\N	\N	\N	2026-03-05 12:31:22.691351-03
67	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:31:22.734778-03
68	empleados	6	crear	\N	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": null, "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:33:09.825025-03:00"}	\N	\N	\N	2026-03-05 12:33:09.825025-03
69	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:33:13.504095-03
70	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:31:22.691351-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:31:22.691351-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:33:46.905044-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:33:46.905044-03:00"}	\N	\N	\N	2026-03-05 12:33:46.905044-03
71	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:33:46.947804-03
72	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": null, "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:33:09.825025-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "inactivo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": null, "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:33:56.834056-03:00"}	\N	\N	\N	2026-03-05 12:33:56.834056-03
73	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:34:04.002492-03
74	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:33:46.905044-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:33:46.905044-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:34:36.657435-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:34:36.657435-03:00"}	\N	\N	\N	2026-03-05 12:34:36.657435-03
76	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "inactivo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": null, "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:33:56.834056-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": null, "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:34:40.873009-03:00"}	\N	\N	\N	2026-03-05 12:34:40.873009-03
77	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 12:34:43.506299-03
78	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": null, "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:34:40.873009-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T12:35:02.9931-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:35:02.9931-03:00"}	\N	\N	\N	2026-03-05 12:35:02.9931-03
79	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 12:35:03.003234-03
80	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T12:34:36.657435-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T12:34:36.657435-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T16:32:19.639851-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T16:32:19.639851-03:00"}	\N	\N	\N	2026-03-05 16:32:19.639851-03
81	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 16:32:19.681723-03
82	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-05 16:36:41.258938-03
83	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T12:35:02.9931-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T12:35:02.9931-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T16:36:57.661533-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T16:36:57.661533-03:00"}	\N	\N	\N	2026-03-05 16:36:57.661533-03
84	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 16:36:57.68784-03
85	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 16:38:15.957465-03
86	solicitudes	29	crear	\N	\N	\N	\N	{"id": 29, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46080402", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T16:39:49.22817-03:00", "fecha_pago": null, "updated_at": "2026-03-05T16:39:49.22817-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T16:39:49.22817-03:00", "nombre_completo": "Matioli ", "numero_solicitud": "CERT-2026-000030", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 16:39:49.22817-03
87	solicitudes	29	actualizar	\N	\N	\N	{"id": 29, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46080402", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T16:39:49.22817-03:00", "fecha_pago": null, "updated_at": "2026-03-05T16:39:49.22817-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T16:39:49.22817-03:00", "nombre_completo": "Matioli ", "numero_solicitud": "CERT-2026-000030", "empleado_asignado_id": null}	{"id": 29, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "46080402", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T16:39:49.22817-03:00", "fecha_pago": "2026-03-05T16:40:13.100294-03:00", "updated_at": "2026-03-05T16:40:13.100294-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T16:39:49.22817-03:00", "nombre_completo": "Matioli ", "numero_solicitud": "CERT-2026-000030", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 16:40:13.100294-03
89	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T16:36:57.661533-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T16:36:57.661533-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T16:40:33.238026-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T16:40:33.238026-03:00"}	\N	\N	\N	2026-03-05 16:40:33.238026-03
90	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 16:40:33.265037-03
91	solicitudes	25	actualizar	\N	\N	\N	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": "2026-03-05T00:08:37.855781-03:00", "updated_at": "2026-03-05T00:08:37.855781-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": null}	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": "2026-03-05T00:08:37.855781-03:00", "updated_at": "2026-03-05T17:11:49.25131-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:11:49.25131-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:11:49.25131-03
92	solicitudes	25	actualizar	\N	\N	\N	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": "2026-03-05T00:08:37.855781-03:00", "updated_at": "2026-03-05T17:11:49.25131-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:11:49.25131-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": 6}	{"id": 25, "email": "mo1844pedro@gmail.com", "estado": "rechazada", "cuit_dni": "46040208", "ciudad_id": 6, "prioridad": "normal", "created_at": "2026-03-05T00:08:02.510321-03:00", "fecha_pago": "2026-03-05T00:08:37.855781-03:00", "updated_at": "2026-03-05T17:12:10.103034-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:11:49.25131-03:00", "motivo_rechazo": "por loco. pusiste mal el dni\\n", "fecha_solicitud": "2026-03-05T00:08:02.510321-03:00", "nombre_completo": "matias oliver", "numero_solicitud": "CERT-2026-000026", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:12:10.103034-03
93	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 17:12:23.310219-03
94	solicitudes	23	actualizar	\N	\N	\N	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": null, "updated_at": "2026-03-05T00:04:55.681943-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": null}	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-05T17:13:49.547861-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 17:13:49.547861-03
96	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T16:40:33.238026-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T16:40:33.238026-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T17:14:20.262702-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T17:14:20.262702-03:00"}	\N	\N	\N	2026-03-05 17:14:20.262702-03
97	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 17:14:20.270424-03
98	solicitudes	23	actualizar	\N	\N	\N	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-05T17:13:49.547861-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": null}	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-05T17:14:25.35594-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:14:25.35594-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:14:25.35594-03
99	solicitudes	23	actualizar	\N	\N	\N	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-05T17:14:25.35594-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:14:25.35594-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": 6}	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-05T17:17:16.71613-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:14:25.35594-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:17:16.71613-03
100	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 17:28:30.300946-03
101	solicitudes	31	crear	\N	\N	\N	\N	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": null, "updated_at": "2026-03-05T17:29:38.072961-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 17:29:38.072961-03
102	solicitudes	31	actualizar	\N	\N	\N	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": null, "updated_at": "2026-03-05T17:29:38.072961-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": null}	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:30:01.781423-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": null}	\N	\N	\N	2026-03-05 17:30:01.781423-03
103	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T17:14:20.262702-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T17:14:20.262702-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T17:30:29.813974-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T17:30:29.813974-03:00"}	\N	\N	\N	2026-03-05 17:30:29.813974-03
104	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-05 17:30:29.822498-03
105	solicitudes	31	actualizar	\N	\N	\N	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:30:01.781423-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": null}	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:30:34.246221-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:30:34.246221-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:30:34.246221-03
106	solicitudes	31	actualizar	\N	\N	\N	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:30:34.246221-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:30:34.246221-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": 6}	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:30:36.260704-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:30:34.246221-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:30:36.260704-03
107	certificados	9	crear	\N	\N	\N	\N	{"id": 9, "es_deudor": true, "created_at": "2026-03-05T17:33:07.056127-03:00", "tipo_deuda": "servicios", "fecha_deuda": null, "monto_deuda": 15000.00, "estado_deuda": null, "solicitud_id": 31, "tamano_bytes": 592602, "fecha_emision": "2026-03-05", "firma_digital": null, "archivo_pdf_hash": "6d96621534de76f98f1c4b237bde4c18492935a8d840fab9b66bd2b4af0b421f", "archivo_pdf_path": "certificados/1772742786911-558562365.pdf", "fecha_vencimiento": "2026-06-03", "numero_expediente": null, "empleado_emisor_id": 6, "numero_certificado": "CERTIF-2026-00000009"}	\N	\N	\N	2026-03-05 17:33:07.056127-03
108	solicitudes	31	actualizar	\N	\N	\N	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:30:36.260704-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:30:34.246221-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": 6}	{"id": 31, "email": "mo1844pedro@gmail.com", "estado": "certificado_emitido", "cuit_dni": "11223344", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T17:29:38.072961-03:00", "fecha_pago": "2026-03-05T17:30:01.781423-03:00", "updated_at": "2026-03-05T17:33:07.12516-03:00", "fecha_emision": "2026-03-05T17:33:07.12516-03:00", "observaciones": null, "fecha_revision": "2026-03-05T17:30:34.246221-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T17:29:38.072961-03:00", "nombre_completo": "Pedro Oliver Matias", "numero_solicitud": "CERT-2026-000032", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-05 17:33:07.12516-03
109	solicitudes	33	crear	\N	\N	\N	\N	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": null, "updated_at": "2026-03-06T14:11:10.89853-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": null}	\N	\N	\N	2026-03-06 14:11:10.89853-03
110	solicitudes	33	actualizar	\N	\N	\N	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": null, "updated_at": "2026-03-06T14:11:10.89853-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": null}	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:11:33.611841-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": null}	\N	\N	\N	2026-03-06 14:11:33.611841-03
112	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-05T17:30:29.813974-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-05T17:30:29.813974-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-06T14:12:01.844093-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T14:12:01.844093-03:00"}	\N	\N	\N	2026-03-06 14:12:01.844093-03
114	solicitudes	33	actualizar	\N	\N	\N	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "pagada", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:11:33.611841-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": null}	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:12:06.516097-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-06T14:12:06.516097-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-06 14:12:06.516097-03
115	solicitudes	33	actualizar	\N	\N	\N	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "en_revision", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:12:06.516097-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-06T14:12:06.516097-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": 6}	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:12:08.331248-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-06T14:12:06.516097-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-06 14:12:08.331248-03
116	certificados	10	crear	\N	\N	\N	\N	{"id": 10, "es_deudor": true, "created_at": "2026-03-06T14:12:31.033371-03:00", "tipo_deuda": "otros", "fecha_deuda": null, "monto_deuda": 12.00, "estado_deuda": null, "solicitud_id": 33, "tamano_bytes": 592602, "fecha_emision": "2026-03-06", "firma_digital": null, "archivo_pdf_hash": "6d96621534de76f98f1c4b237bde4c18492935a8d840fab9b66bd2b4af0b421f", "archivo_pdf_path": "certificados/1772817150829-106231733.pdf", "fecha_vencimiento": "2026-06-04", "numero_expediente": null, "empleado_emisor_id": 6, "numero_certificado": "CERTIF-2026-00000010"}	\N	\N	\N	2026-03-06 14:12:31.033371-03
117	solicitudes	33	actualizar	\N	\N	\N	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:12:08.331248-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-06T14:12:06.516097-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": 6}	{"id": 33, "email": "mo1844pedro@gmail.com", "estado": "certificado_emitido", "cuit_dni": "12312312", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:11:10.89853-03:00", "fecha_pago": "2026-03-06T14:11:33.611841-03:00", "updated_at": "2026-03-06T14:12:31.087446-03:00", "fecha_emision": "2026-03-06T14:12:31.087446-03:00", "observaciones": null, "fecha_revision": "2026-03-06T14:12:06.516097-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:11:10.89853-03:00", "nombre_completo": "Matias Acevedo Rojas", "numero_solicitud": "CERT-2026-000034", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-06 14:12:31.087446-03
118	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 14:12:38.259042-03
120	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-05T16:32:19.639851-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-05T16:32:19.639851-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-06T14:16:34.630284-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-06T14:16:34.630284-03:00"}	\N	\N	\N	2026-03-06 14:16:34.630284-03
121	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-06 14:16:34.680613-03
122	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-06 14:19:09.341884-03
123	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-06T14:16:34.630284-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-06T14:16:34.630284-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-06T14:19:39.86368-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-06T14:19:39.86368-03:00"}	\N	\N	\N	2026-03-06 14:19:39.86368-03
124	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-06 14:19:39.881557-03
125	empleados	1	logout	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-06 14:19:50.571566-03
126	solicitudes	35	crear	\N	\N	\N	\N	{"id": 35, "email": "mo1844pedro@gmail.com", "estado": "pendiente_pago", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-06T14:20:43.174328-03:00", "fecha_pago": null, "updated_at": "2026-03-06T14:20:43.174328-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": null, "motivo_rechazo": null, "fecha_solicitud": "2026-03-06T14:20:43.174328-03:00", "nombre_completo": "Maximiliano Di Pasquale", "numero_solicitud": "CERT-2026-000036", "empleado_asignado_id": null}	\N	\N	\N	2026-03-06 14:20:43.174328-03
127	empleados	1	actualizar	\N	\N	\N	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-06T14:19:39.86368-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-06T14:19:39.86368-03:00"}	{"id": 1, "rol": "administrador", "email": "admin@gobierno.gob.ar", "estado": "activo", "nombre": "Carlos Fernández", "ciudad_id": null, "password_hash": "$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K", "ultimo_acceso": "2026-03-06T15:08:05.863747-03:00", "fecha_creacion": "2026-02-26T12:44:53.332707-03:00", "fecha_actualizacion": "2026-03-06T15:08:05.863747-03:00"}	\N	\N	\N	2026-03-06 15:08:05.863747-03
128	empleados	1	login	1	admin@gobierno.gob.ar	administrador	\N	\N	\N	\N	\N	2026-03-06 15:08:05.905809-03
129	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-06T14:12:01.844093-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T14:12:01.844093-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-06T15:40:36.13571-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T15:40:36.13571-03:00"}	\N	\N	\N	2026-03-06 15:40:36.13571-03
130	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 15:40:36.191801-03
131	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-06T15:40:36.13571-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T15:40:36.13571-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-06T18:31:23.38323-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T18:31:23.38323-03:00"}	\N	\N	\N	2026-03-06 18:31:23.38323-03
132	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 18:31:23.480562-03
133	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$XxsCgyvcA9b/BSZmQ8DLvuX53M36AQoiNI/NeSvB3gG6T9FPs88Bi", "ultimo_acceso": "2026-03-06T18:31:23.38323-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T18:31:23.38323-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T18:31:23.38323-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T18:57:13.279059-03:00"}	\N	\N	\N	2026-03-06 18:57:13.279059-03
134	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 18:57:20.321046-03
135	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T18:31:23.38323-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T18:57:13.279059-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T18:57:35.863947-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T18:57:35.863947-03:00"}	\N	\N	\N	2026-03-06 18:57:35.863947-03
136	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 18:57:35.870732-03
137	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 18:58:01.484479-03
138	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T18:57:35.863947-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T18:57:35.863947-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T19:05:38.491568-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T19:05:38.491568-03:00"}	\N	\N	\N	2026-03-06 19:05:38.491568-03
139	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 19:05:38.525048-03
140	empleados	6	logout	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 19:09:57.332268-03
141	empleados	6	actualizar	\N	\N	\N	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T19:05:38.491568-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T19:05:38.491568-03:00"}	{"id": 6, "rol": "empleado", "email": "nico.oliver@gobierno.gob.ar", "estado": "activo", "nombre": "Nicolas Oliver", "ciudad_id": 1, "password_hash": "$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG", "ultimo_acceso": "2026-03-06T19:10:48.186215-03:00", "fecha_creacion": "2026-03-05T12:33:09.825025-03:00", "fecha_actualizacion": "2026-03-06T19:10:48.186215-03:00"}	\N	\N	\N	2026-03-06 19:10:48.186215-03
142	empleados	6	login	6	nico.oliver@gobierno.gob.ar	empleado	\N	\N	\N	\N	\N	2026-03-06 19:10:48.230445-03
143	certificados	11	crear	\N	\N	\N	\N	{"id": 11, "es_deudor": false, "created_at": "2026-03-06T19:10:55.286926-03:00", "tipo_deuda": null, "fecha_deuda": null, "monto_deuda": null, "estado_deuda": null, "solicitud_id": 13, "tamano_bytes": 664315, "fecha_emision": "2026-03-06", "firma_digital": null, "archivo_pdf_hash": "54af76f351f7f8c6bb60835464092ea6a7cf92629f009a6d5fee325b23da46e4", "archivo_pdf_path": "certificados/1772835055188-401848811.pdf", "fecha_vencimiento": "2026-06-04", "numero_expediente": null, "empleado_emisor_id": 6, "numero_certificado": "CERTIF-2026-00000011"}	\N	\N	\N	2026-03-06 19:10:55.286926-03
144	solicitudes	13	actualizar	\N	\N	\N	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-03-03T16:24:35.953119-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-03T16:24:26.783128-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	{"id": 13, "email": "mo1844pedro@gmail.com", "estado": "certificado_emitido", "cuit_dni": "12345678", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-02-27T10:52:32.66158-03:00", "fecha_pago": "2026-02-27T10:55:01.65192-03:00", "updated_at": "2026-03-06T19:10:55.328481-03:00", "fecha_emision": "2026-03-06T19:10:55.328481-03:00", "observaciones": null, "fecha_revision": "2026-03-03T16:24:26.783128-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-02-27T10:52:32.66158-03:00", "nombre_completo": "Matias Pedro Oliver", "numero_solicitud": "CERT-2026-000014", "empleado_asignado_id": null}	\N	\N	\N	2026-03-06 19:10:55.328481-03
145	certificados	12	crear	\N	\N	\N	\N	{"id": 12, "es_deudor": true, "created_at": "2026-03-06T19:25:23.817171-03:00", "tipo_deuda": null, "fecha_deuda": null, "monto_deuda": 123.00, "estado_deuda": null, "solicitud_id": 23, "tamano_bytes": 664315, "fecha_emision": "2026-03-06", "firma_digital": null, "archivo_pdf_hash": "54af76f351f7f8c6bb60835464092ea6a7cf92629f009a6d5fee325b23da46e4", "archivo_pdf_path": "certificados/1772835923595-567701709.pdf", "fecha_vencimiento": "2026-06-04", "numero_expediente": null, "empleado_emisor_id": 6, "numero_certificado": "CERTIF-2026-00000012"}	\N	\N	\N	2026-03-06 19:25:23.817171-03
146	solicitudes	23	actualizar	\N	\N	\N	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "aprobada", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-05T17:17:16.71613-03:00", "fecha_emision": null, "observaciones": null, "fecha_revision": "2026-03-05T17:14:25.35594-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": 6}	{"id": 23, "email": "mo1844pedro@gmail.com", "estado": "certificado_emitido", "cuit_dni": "46040208", "ciudad_id": 1, "prioridad": "normal", "created_at": "2026-03-05T00:04:55.681943-03:00", "fecha_pago": "2026-03-05T17:13:49.547861-03:00", "updated_at": "2026-03-06T19:25:23.872279-03:00", "fecha_emision": "2026-03-06T19:25:23.872279-03:00", "observaciones": null, "fecha_revision": "2026-03-05T17:14:25.35594-03:00", "motivo_rechazo": null, "fecha_solicitud": "2026-03-05T00:04:55.681943-03:00", "nombre_completo": "Matias Oliver", "numero_solicitud": "CERT-2026-000024", "empleado_asignado_id": 6}	\N	\N	\N	2026-03-06 19:25:23.872279-03
\.


--
-- TOC entry 5167 (class 0 OID 17743)
-- Dependencies: 232
-- Data for Name: certificados; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.certificados (id, solicitud_id, empleado_emisor_id, numero_certificado, archivo_pdf_path, archivo_pdf_hash, fecha_emision, firma_digital, es_deudor, monto_deuda, tipo_deuda, estado_deuda, numero_expediente, fecha_deuda, tamano_bytes, created_at) FROM stdin;
1	1	1	CERTIF-2026-00000001	certificados/1772147834325-454169614.pdf	16ec95bd673a70a3f2204de7abc2104b76eb0f8543cf34871e1334293e711115	2026-02-26	\N	f	\N	\N	\N	\N	\N	706822	2026-02-26 20:17:14.943762-03
9	31	6	CERTIF-2026-00000009	certificados/1772742786911-558562365.pdf	6d96621534de76f98f1c4b237bde4c18492935a8d840fab9b66bd2b4af0b421f	2026-03-05	\N	t	15000.00	servicios	\N	\N	\N	592602	2026-03-05 17:33:07.056127-03
10	33	6	CERTIF-2026-00000010	certificados/1772817150829-106231733.pdf	6d96621534de76f98f1c4b237bde4c18492935a8d840fab9b66bd2b4af0b421f	2026-03-06	\N	t	12.00	otros	\N	\N	\N	592602	2026-03-06 14:12:31.033371-03
11	13	6	CERTIF-2026-00000011	certificados/1772835055188-401848811.pdf	54af76f351f7f8c6bb60835464092ea6a7cf92629f009a6d5fee325b23da46e4	2026-03-06	\N	f	\N	\N	\N	\N	\N	664315	2026-03-06 19:10:55.286926-03
12	23	6	CERTIF-2026-00000012	certificados/1772835923595-567701709.pdf	54af76f351f7f8c6bb60835464092ea6a7cf92629f009a6d5fee325b23da46e4	2026-03-06	\N	t	123.00	\N	\N	\N	\N	664315	2026-03-06 19:25:23.817171-03
\.


--
-- TOC entry 5159 (class 0 OID 17629)
-- Dependencies: 224
-- Data for Name: ciudades; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.ciudades (id, nombre, provincia, estado, created_at, updated_at) FROM stdin;
1	Santa Fe	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
2	Rosario	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
3	Venado Tuerto	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
4	Rafaela	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
5	Santo Tomé	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
6	Funes	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
7	Reconquista	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
8	Villa Constitución	Santa Fe	activa	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
\.


--
-- TOC entry 5171 (class 0 OID 17800)
-- Dependencies: 236
-- Data for Name: configuracion; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.configuracion (id, clave, valor, tipo, descripcion, updated_by, updated_at, created_at) FROM stdin;
2	metodos_pago_habilitados	["tarjeta_credito","tarjeta_debito","transferencia","efectivo"]	json	Array JSON con métodos de pago habilitados en PlusPagos.	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
3	email_soporte	soporte@gobierno.gob.ar	texto	Email de contacto para soporte ciudadano.	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
4	duracion_otp_minutos	10	numero	Minutos de validez de un código OTP desde su generación.	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
5	max_intentos_otp	3	numero	Cantidad máxima de intentos para validar un código OTP.	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
6	dias_vigencia_certificado	90	numero	Días de vigencia de un certificado emitido.	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
7	texto_terminos_condiciones		texto	Términos y Condiciones (Ley 24.240).	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
8	texto_aviso_privacidad		texto	Aviso de Privacidad (Ley 25.326).	\N	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03
1	monto_certificado	8	numero	Monto en ARS para solicitar un certificado de deudor.	1	2026-03-06 14:19:06.308389-03	2026-02-26 12:44:53.332707-03
\.


--
-- TOC entry 5161 (class 0 OID 17648)
-- Dependencies: 226
-- Data for Name: empleados; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.empleados (id, nombre, email, password_hash, estado, rol, ciudad_id, fecha_creacion, fecha_actualizacion, ultimo_acceso) FROM stdin;
2	María López	empleado@gobierno.gob.ar	$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR	activo	empleado	1	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03	\N
4	Roberto Silva	roberto.silva@gobierno.gob.ar	$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR	activo	empleado	4	2026-02-26 12:44:53.332707-03	2026-02-26 12:44:53.332707-03	\N
6	Nicolas Oliver	nico.oliver@gobierno.gob.ar	$2b$12$76pC.RE4TL7GZBEgTaVQHOsJDQI7TDU.zzAefVm8ioGRCqE2rbHQG	activo	empleado	1	2026-03-05 12:33:09.825025-03	2026-03-06 19:10:48.186215-03	2026-03-06 19:10:48.186215-03
3	Ana Martínez	ana.martinez@gobierno.gob.ar	$2b$12$HASH_GENERADO_POR_APLICACION_NO_HARDCODEAR	activo	empleado	3	2026-02-26 12:44:53.332707-03	2026-03-04 18:58:46.797571-03	\N
5	Matias Pedro	matipe@gobierno.gob.ar	$2b$12$VOqvaAW5GKrWoWp4GFv9c.rP1CNWNhVM7hrLQXbZQAdlTzxkJBHDq	activo	empleado	\N	2026-03-04 19:04:08.204435-03	2026-03-04 19:04:08.204435-03	\N
1	Carlos Fernández	admin@gobierno.gob.ar	$2b$12$xJs.1cc8Rh.yyIb8zf47Ee4XmWPZNC4VKS41VTC62XgbmR3oQhm4K	activo	administrador	\N	2026-02-26 12:44:53.332707-03	2026-03-06 15:08:05.863747-03	2026-03-06 15:08:05.863747-03
\.


--
-- TOC entry 5173 (class 0 OID 17824)
-- Dependencies: 238
-- Data for Name: otp_sessions; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.otp_sessions (id, email, cuit_dni, codigo_otp_hash, intentos, expira_at, usado, created_at) FROM stdin;
2	aribag.clari@gmail.com	12345678	$2b$12$ExEKf/huv/gs6DXAHvKmyeWbc3uLbPQmYsAsjOFx3zAVriG7oVZhW	0	2026-02-26 16:51:51.417-03	f	2026-02-26 16:41:51.419404-03
1	mo1844pedro@gmail.com	12345678	$2b$12$cBArUVqF5T90/dBMNfRO6u.mC8Is9rIPJ2tqWwNoNKofAmNOQt9Q.	0	2026-02-26 16:45:49.137-03	t	2026-02-26 16:35:49.148208-03
3	mo1844pedro@gmail.com	12345678	$2b$12$eOKhA1V2guPOej5MQOE53OBuiDE9Q6eSvYidlD4wtPHSCFkD1wJLm	0	2026-02-26 16:59:13.291-03	t	2026-02-26 16:49:13.293196-03
4	mo1844pedro@gmail.com	12345678	$2b$12$U6qIR9NaDgULpJlwEC2nCuRUax3xi.QoXCP638qTlzGbmCdZsvnQO	0	2026-02-26 20:00:37.292-03	t	2026-02-26 19:50:37.314811-03
5	mo1844pedro@gmail.com	12345678	$2b$12$5sq2gSQOIndbqZKqu4mfLugQP5Ma2Ir9PUyEpcHs8Htj8ptJHY/Wq	0	2026-02-27 11:00:22.914-03	t	2026-02-27 10:50:22.919835-03
6	mo1844pedro@gmail.com	12345678	$2b$12$Qfo8IgghyNs5jx79nIoQw.iGo//xBw1CMqQ69dPGgz7dQa.4ZjXrq	0	2026-02-27 14:05:02.079-03	t	2026-02-27 13:55:02.101744-03
22	mo1844pedro@gmail.com	12345678	$2b$12$EzSPO7Q5C0qVdypOgN6NP.ciA1euk5Iv.HRK0I9AMftU/LZqCD4sK	0	2026-03-05 12:25:20.821-03	t	2026-03-05 12:15:20.826874-03
7	mo1844pedro@gmail.com	46040208	$2b$12$58vYeREgBj2vzIPqMDt3suusSBxFNjxJuwX6g2/9Kc2sW6l/Eraq.	2	2026-02-27 14:55:41.036-03	t	2026-02-27 14:45:41.038105-03
23	matiaspeoliver@gmail.com	12345678	$2b$12$oQyjJ1tTdX0vVxxsXEkb0uMg4oB1aJ5DkSJKbO2VS1xuHyBCpwcli	0	2026-03-05 12:26:43.169-03	t	2026-03-05 12:16:43.172238-03
9	mo1844pedro@gmail.com	4604020	$2b$12$hV4w1DOaiHu3jPMVau9UTOa/4J.AoI8fmLwjXFQ8WLhXAO0cguGha	1	2026-03-01 12:00:32.954-03	t	2026-03-01 11:50:32.955995-03
24	matiaspeoliver@gmail.com	12345678	$2b$12$G.Xemdoyc0DpUtUT/O6HsueuynPoGUycFSrOBo24HqiLE6ELi5/Ye	0	2026-03-05 12:31:11.28-03	t	2026-03-05 12:21:11.281247-03
8	mo1844pedro@gmail.com	46040208	$2b$12$kZlnM9QXyAk5ryieVeYbge05W7UqOvz4s7VSonU4jhUP.FLSyEdR.	3	2026-03-01 11:57:32.139-03	t	2026-03-01 11:47:32.142714-03
10	mo1844pedro@gmail.com	46040208	$2b$12$WEsS6QiuH48vybe1.cnhO.rqEbPOAp0OnyA8t0avplukkoH30v/by	0	2026-03-01 17:21:58.407-03	t	2026-03-01 17:11:58.409245-03
11	pirroliver@gmail.com	46040208	$2b$12$wDo7TaJmnJ7O.R6obWzd6.z6IF02eywGCCS21.s5BZ2Wdl13zWPQq	0	2026-03-01 17:40:36.891-03	f	2026-03-01 17:30:36.894616-03
12	mo1844pedro@gmail.com	46040208	$2b$12$TAU1cMayaonk0EWscrFjyuIntlwScUXoif8Uyj.auUgCgMlVixcu6	0	2026-03-03 16:40:06.74-03	t	2026-03-03 16:30:06.742631-03
14	matiaspeoliver@gmail.com	46040208	$2b$12$LKaUtiSGD6CKl5yqG5dLu..rdqvQMGDQn7j.WPfjzW0by1R5Q0Ci.	0	2026-03-04 19:41:02.018-03	t	2026-03-04 19:31:02.023829-03
13	mo1844pedro@gmail.com	46040208	$2b$12$BUfU.Lyntw5YRO7b58MGWu.ZJaq103GYRCDgpFEGvUf1zdPZeihie	0	2026-03-04 14:30:29.679-03	t	2026-03-04 14:20:29.689761-03
15	mo1844pedro@gmail.com	46040208	$2b$12$uU9rtm4snGlt/BInVfOH9O/vmnn/0WAPAplgVKscAgEVwCqtEzNoC	0	2026-03-05 00:07:50.62-03	t	2026-03-04 23:57:50.623985-03
16	mo1844pedro@gmail.com	46040208	$2b$12$gpIy6jg6xnXJjPNlIegRWek9AKb3LOJocdkUCMUSOPYcIPldmRIEm	0	2026-03-05 12:01:57.761-03	t	2026-03-05 11:51:57.764414-03
25	mo1844pedro@gmail.com	87654321	$2b$12$jsxykEdiIthRJDsL4KjNvu9mb2hAqggOg6xj5G.faPFbGZUbJyesO	0	2026-03-05 12:35:10.226-03	t	2026-03-05 12:25:10.228507-03
17	mo1844pedro@gmail.com	46040208	$2b$12$ucYR07khjZ6nCc7Kxkp/U.NnmciwuCoxJvYrPU3K4Ofyz22yOEqEO	1	2026-03-05 12:07:11.095-03	t	2026-03-05 11:57:11.102444-03
18	mo1844pedro@gmail.com	46040208	$2b$12$AudMlSazz1Vmp2ZeqywdL.fu8wMtzi4fXXf.1.pZb/gY7sWZ5jody	0	2026-03-05 12:10:08.619-03	t	2026-03-05 12:00:08.621692-03
19	matiaspeoliver@gmail.com	12345678	$2b$12$DImJHygT05J4HWgurmnUwuNoJ53gHfNin9tF5J8w.Tn4QwJTVp/Hi	0	2026-03-05 12:14:39.652-03	t	2026-03-05 12:04:39.652842-03
20	matiaspeoliver@gmail.com	46040208	$2b$12$mD3zUPBoa44c0Z7VyvrtjekQ8gpwFZ059coVFHKb8gUD0IEOgjbDO	0	2026-03-05 12:19:18.227-03	t	2026-03-05 12:09:18.240813-03
21	mo1844pedro@gmail.com	12345678	$2b$12$LD/mOWSaW8JCDMHonXrIB.ua.bxuOo1uv5bVVpqJY9/NsXgnlZdVS	0	2026-03-05 12:22:32.661-03	t	2026-03-05 12:12:32.674592-03
26	mo1844pedro@gmail.com	46040280	$2b$12$gxlF6rD0OPpUdztB.FgtOux0Ha6ojiki7GChjXn8PU4iH3mncYymy	0	2026-03-05 12:38:08.479-03	t	2026-03-05 12:28:08.481585-03
27	mo1844pedro@gmail.com	44448888	$2b$12$/pOz6K.39a53tRjaLrVpDOiFWeP7fLv1ZQx19ZQtB3./LKbc4GiTu	0	2026-03-05 16:48:39.854-03	t	2026-03-05 16:38:39.856363-03
28	mo1844pedro@gmail.com	46040208	$2b$12$YJwED.R4gmd0FTTbWE9sE.4kXNyWipNbND.uWXYBnYsCO57iHOM2K	0	2026-03-05 17:22:44.239-03	t	2026-03-05 17:12:44.240765-03
29	mo1844pedro@gmail.com	11223344	$2b$12$cJQBK8bfZe092V.uPOujxe0Gywho2y3kXe3.JIJb4CMERMQfqlhRG	0	2026-03-05 17:38:55.042-03	t	2026-03-05 17:28:55.044098-03
30	mo1844pedro@gmail.com	12345678	$2b$12$ccYIWOIorZTrWvhgc7nLdenkDO.R3EATIO3fHlBucl/ZjmGYDnMDu	0	2026-03-05 23:46:31.792-03	t	2026-03-05 23:36:31.7946-03
31	mo1844pedro@gmail.com	46040208	$2b$12$dkQbdOWJRX7wm4Uq9IkAgOK./Wz0DlpxDuOjYcLOSQFzpJGBGPn1C	0	2026-03-06 14:20:01.231-03	t	2026-03-06 14:10:01.24095-03
32	mo1844pedro@gmail.com	46040208	$2b$12$DTdr9yK/rRFAvIkjVpf5FOfOxUU6Jw4Ug4dcUsUnNDqO951OMLjCi	0	2026-03-06 14:22:58.807-03	t	2026-03-06 14:12:58.811939-03
33	mo1844pedro@gmail.com	46040208	$2b$12$w4rUjnLJq0bgsMB0I155XOlKA4f2pzWyUbjUuw7UHrqJ8awET6p0S	0	2026-03-06 14:30:07.092-03	t	2026-03-06 14:20:07.096608-03
34	mo1844pedro@gmail.com	46040208	$2b$12$1BNwx2okV6kcBXUoHq1p8.Rvk52FcE1cn3pmOfflLrBQfNz/RMzxO	0	2026-03-06 14:42:28.25-03	t	2026-03-06 14:32:28.251758-03
35	mo1844pedro@gmail.com	46040208	$2b$12$V4uYmIlF.EvHGHN9Kh7.k.qUo48AmwKBnoIXU/zvV9xB8TIGoUrtu	0	2026-03-06 15:20:58.89-03	t	2026-03-06 15:10:58.894463-03
\.


--
-- TOC entry 5163 (class 0 OID 17677)
-- Dependencies: 228
-- Data for Name: solicitudes; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.solicitudes (id, numero_solicitud, nombre_completo, cuit_dni, email, ciudad_id, estado, prioridad, empleado_asignado_id, observaciones, motivo_rechazo, fecha_solicitud, fecha_pago, fecha_revision, fecha_emision, created_at, updated_at) FROM stdin;
1	CERT-2026-000002	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	certificado_emitido	normal	\N	\N	\N	2026-02-26 19:54:23.38444-03	\N	\N	2026-02-26 20:17:15.049951-03	2026-02-26 19:54:23.38444-03	2026-02-26 20:17:15.049951-03
3	CERT-2026-000004	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-02-26 22:10:50.490346-03	\N	\N	\N	2026-02-26 22:10:50.490346-03	2026-02-26 22:10:50.490346-03
5	CERT-2026-000006	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-02-26 22:16:47.421498-03	\N	\N	\N	2026-02-26 22:16:47.421498-03	2026-02-26 22:16:47.421498-03
7	CERT-2026-000008	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-02-26 22:24:22.023627-03	\N	\N	\N	2026-02-26 22:24:22.023627-03	2026-02-26 22:24:22.023627-03
9	CERT-2026-000010	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-02-26 22:24:47.203091-03	\N	\N	\N	2026-02-26 22:24:47.203091-03	2026-02-26 22:24:47.203091-03
11	CERT-2026-000012	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-02-26 22:27:22.180888-03	\N	\N	\N	2026-02-26 22:27:22.180888-03	2026-02-26 22:27:22.180888-03
15	CERT-2026-000016	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	rechazada	normal	\N	\N	No se encuentra persona con ese CUIT/DNI y nombre	2026-02-27 13:56:05.231204-03	2026-02-27 13:59:56.988481-03	2026-03-03 16:25:44.850383-03	\N	2026-02-27 13:56:05.231204-03	2026-03-03 16:27:08.012936-03
17	CERT-2026-000018	Matias Oliver	46040208	matiaspeoliver@gmail.com	1	cancelada	normal	\N	\N	\N	2026-03-04 19:31:44.231235-03	\N	\N	\N	2026-03-04 19:31:44.231235-03	2026-03-04 19:31:50.601395-03
19	CERT-2026-000020	Matias Oliver	46040208	matiaspeoliver@gmail.com	1	cancelada	normal	\N	\N	\N	2026-03-04 19:33:10.347764-03	\N	\N	\N	2026-03-04 19:33:10.347764-03	2026-03-04 19:37:04.420512-03
21	CERT-2026-000022	Matias Pedro Oliver	46040208	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-03-04 23:58:51.964237-03	\N	\N	\N	2026-03-04 23:58:51.964237-03	2026-03-04 23:58:51.964237-03
27	CERT-2026-000028	Pedro Oliver	46040209	mo1844pedro@gmail.com	1	pagada	normal	\N	\N	\N	2026-03-05 12:29:36.449829-03	2026-03-05 12:30:03.288286-03	\N	\N	2026-03-05 12:29:36.449829-03	2026-03-05 12:30:03.288286-03
29	CERT-2026-000030	Matioli 	46080402	mo1844pedro@gmail.com	1	pagada	normal	\N	\N	\N	2026-03-05 16:39:49.22817-03	2026-03-05 16:40:13.100294-03	\N	\N	2026-03-05 16:39:49.22817-03	2026-03-05 16:40:13.100294-03
25	CERT-2026-000026	matias oliver	46040208	mo1844pedro@gmail.com	6	rechazada	normal	6	\N	por loco. pusiste mal el dni\n	2026-03-05 00:08:02.510321-03	2026-03-05 00:08:37.855781-03	2026-03-05 17:11:49.25131-03	\N	2026-03-05 00:08:02.510321-03	2026-03-05 17:12:10.103034-03
31	CERT-2026-000032	Pedro Oliver Matias	11223344	mo1844pedro@gmail.com	1	certificado_emitido	normal	6	\N	\N	2026-03-05 17:29:38.072961-03	2026-03-05 17:30:01.781423-03	2026-03-05 17:30:34.246221-03	2026-03-05 17:33:07.12516-03	2026-03-05 17:29:38.072961-03	2026-03-05 17:33:07.12516-03
33	CERT-2026-000034	Matias Acevedo Rojas	12312312	mo1844pedro@gmail.com	1	certificado_emitido	normal	6	\N	\N	2026-03-06 14:11:10.89853-03	2026-03-06 14:11:33.611841-03	2026-03-06 14:12:06.516097-03	2026-03-06 14:12:31.087446-03	2026-03-06 14:11:10.89853-03	2026-03-06 14:12:31.087446-03
35	CERT-2026-000036	Maximiliano Di Pasquale	12345678	mo1844pedro@gmail.com	1	pendiente_pago	normal	\N	\N	\N	2026-03-06 14:20:43.174328-03	\N	\N	\N	2026-03-06 14:20:43.174328-03	2026-03-06 14:20:43.174328-03
13	CERT-2026-000014	Matias Pedro Oliver	12345678	mo1844pedro@gmail.com	1	certificado_emitido	normal	\N	\N	\N	2026-02-27 10:52:32.66158-03	2026-02-27 10:55:01.65192-03	2026-03-03 16:24:26.783128-03	2026-03-06 19:10:55.328481-03	2026-02-27 10:52:32.66158-03	2026-03-06 19:10:55.328481-03
23	CERT-2026-000024	Matias Oliver	46040208	mo1844pedro@gmail.com	1	certificado_emitido	normal	6	\N	\N	2026-03-05 00:04:55.681943-03	2026-03-05 17:13:49.547861-03	2026-03-05 17:14:25.35594-03	2026-03-06 19:25:23.872279-03	2026-03-05 00:04:55.681943-03	2026-03-06 19:25:23.872279-03
\.


--
-- TOC entry 5165 (class 0 OID 17716)
-- Dependencies: 230
-- Data for Name: transacciones; Type: TABLE DATA; Schema: portal; Owner: postgres
--

COPY portal.transacciones (id, solicitud_id, monto, estado, metodo_pago, referencia_pluspagos, codigo_autorizacion, mensaje_error, fecha_transaccion, fecha_confirmacion, created_at) FROM stdin;
1	11	8000.00	exitoso	\N	475835	475835	\N	2026-02-26 22:33:01.947656-03	2026-02-26 22:33:01.947656-03	2026-02-26 22:33:01.947656-03
2	13	8000.00	exitoso	\N	515629	515629	\N	2026-02-27 10:55:01.425682-03	2026-02-27 10:55:01.425682-03	2026-02-27 10:55:01.425682-03
3	15	8000.00	exitoso	\N	217223	217223	\N	2026-02-27 13:59:56.939886-03	2026-02-27 13:59:56.939886-03	2026-02-27 13:59:56.939886-03
4	25	9000.00	exitoso	\N	250084	250084	\N	2026-03-05 00:08:37.786647-03	2026-03-05 00:08:37.786647-03	2026-03-05 00:08:37.786647-03
6	27	9000.00	exitoso	\N	756264	756264	\N	2026-03-05 12:30:03.268216-03	2026-03-05 12:30:03.268216-03	2026-03-05 12:30:03.268216-03
8	29	9000.00	exitoso	\N	359232	359232	\N	2026-03-05 16:40:13.090842-03	2026-03-05 16:40:13.090842-03	2026-03-05 16:40:13.090842-03
9	23	9000.00	exitoso	\N	805721	805721	\N	2026-03-05 17:13:49.530767-03	2026-03-05 17:13:49.530767-03	2026-03-05 17:13:49.530767-03
10	31	9000.00	exitoso	\N	725079	725079	\N	2026-03-05 17:30:01.775427-03	2026-03-05 17:30:01.775427-03	2026-03-05 17:30:01.775427-03
11	33	9000.00	exitoso	\N	684479	684479	\N	2026-03-06 14:11:33.583765-03	2026-03-06 14:11:33.583765-03	2026-03-06 14:11:33.583765-03
\.


--
-- TOC entry 5199 (class 0 OID 0)
-- Dependencies: 233
-- Name: auditoria_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.auditoria_id_seq', 146, true);


--
-- TOC entry 5200 (class 0 OID 0)
-- Dependencies: 231
-- Name: certificados_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.certificados_id_seq', 12, true);


--
-- TOC entry 5201 (class 0 OID 0)
-- Dependencies: 223
-- Name: ciudades_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.ciudades_id_seq', 8, true);


--
-- TOC entry 5202 (class 0 OID 0)
-- Dependencies: 235
-- Name: configuracion_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.configuracion_id_seq', 8, true);


--
-- TOC entry 5203 (class 0 OID 0)
-- Dependencies: 225
-- Name: empleados_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.empleados_id_seq', 6, true);


--
-- TOC entry 5204 (class 0 OID 0)
-- Dependencies: 237
-- Name: otp_sessions_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.otp_sessions_id_seq', 35, true);


--
-- TOC entry 5205 (class 0 OID 0)
-- Dependencies: 222
-- Name: seq_numero_certificado; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.seq_numero_certificado', 12, true);


--
-- TOC entry 5206 (class 0 OID 0)
-- Dependencies: 227
-- Name: solicitudes_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.solicitudes_id_seq', 36, true);


--
-- TOC entry 5207 (class 0 OID 0)
-- Dependencies: 229
-- Name: transacciones_id_seq; Type: SEQUENCE SET; Schema: portal; Owner: postgres
--

SELECT pg_catalog.setval('portal.transacciones_id_seq', 11, true);


--
-- TOC entry 4979 (class 2606 OID 17793)
-- Name: auditoria pk_auditoria; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.auditoria
    ADD CONSTRAINT pk_auditoria PRIMARY KEY (id);


--
-- TOC entry 4967 (class 2606 OID 17765)
-- Name: certificados pk_certificados; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.certificados
    ADD CONSTRAINT pk_certificados PRIMARY KEY (id);


--
-- TOC entry 4926 (class 2606 OID 17644)
-- Name: ciudades pk_ciudades; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.ciudades
    ADD CONSTRAINT pk_ciudades PRIMARY KEY (id);


--
-- TOC entry 4982 (class 2606 OID 17815)
-- Name: configuracion pk_configuracion; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.configuracion
    ADD CONSTRAINT pk_configuracion PRIMARY KEY (id);


--
-- TOC entry 4933 (class 2606 OID 17668)
-- Name: empleados pk_empleados; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.empleados
    ADD CONSTRAINT pk_empleados PRIMARY KEY (id);


--
-- TOC entry 4989 (class 2606 OID 17844)
-- Name: otp_sessions pk_otp_sessions; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.otp_sessions
    ADD CONSTRAINT pk_otp_sessions PRIMARY KEY (id);


--
-- TOC entry 4949 (class 2606 OID 17702)
-- Name: solicitudes pk_solicitudes; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.solicitudes
    ADD CONSTRAINT pk_solicitudes PRIMARY KEY (id);


--
-- TOC entry 4957 (class 2606 OID 17734)
-- Name: transacciones pk_transacciones; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.transacciones
    ADD CONSTRAINT pk_transacciones PRIMARY KEY (id);


--
-- TOC entry 4969 (class 2606 OID 17767)
-- Name: certificados uq_certificados_numero; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.certificados
    ADD CONSTRAINT uq_certificados_numero UNIQUE (numero_certificado);


--
-- TOC entry 4971 (class 2606 OID 17769)
-- Name: certificados uq_certificados_solicitud; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.certificados
    ADD CONSTRAINT uq_certificados_solicitud UNIQUE (solicitud_id);


--
-- TOC entry 4928 (class 2606 OID 17646)
-- Name: ciudades uq_ciudades_nombre; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.ciudades
    ADD CONSTRAINT uq_ciudades_nombre UNIQUE (nombre);


--
-- TOC entry 4984 (class 2606 OID 17817)
-- Name: configuracion uq_configuracion_clave; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.configuracion
    ADD CONSTRAINT uq_configuracion_clave UNIQUE (clave);


--
-- TOC entry 4935 (class 2606 OID 17670)
-- Name: empleados uq_empleados_email; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.empleados
    ADD CONSTRAINT uq_empleados_email UNIQUE (email);


--
-- TOC entry 4951 (class 2606 OID 17704)
-- Name: solicitudes uq_solicitudes_numero; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.solicitudes
    ADD CONSTRAINT uq_solicitudes_numero UNIQUE (numero_solicitud);


--
-- TOC entry 4959 (class 2606 OID 17736)
-- Name: transacciones uq_transacciones_referencia; Type: CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.transacciones
    ADD CONSTRAINT uq_transacciones_referencia UNIQUE (referencia_pluspagos);


--
-- TOC entry 4972 (class 1259 OID 17883)
-- Name: idx_auditoria_accion; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_auditoria_accion ON portal.auditoria USING btree (accion);


--
-- TOC entry 4973 (class 1259 OID 17882)
-- Name: idx_auditoria_created_at; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_auditoria_created_at ON portal.auditoria USING btree (created_at DESC);


--
-- TOC entry 4974 (class 1259 OID 17880)
-- Name: idx_auditoria_tabla_registro; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_auditoria_tabla_registro ON portal.auditoria USING btree (tabla_afectada, registro_id);


--
-- TOC entry 4975 (class 1259 OID 17881)
-- Name: idx_auditoria_usuario; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_auditoria_usuario ON portal.auditoria USING btree (usuario_id) WHERE (usuario_id IS NOT NULL);


--
-- TOC entry 4976 (class 1259 OID 17884)
-- Name: idx_auditoria_valores_anteriores_gin; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_auditoria_valores_anteriores_gin ON portal.auditoria USING gin (valores_anteriores);


--
-- TOC entry 4977 (class 1259 OID 17885)
-- Name: idx_auditoria_valores_nuevos_gin; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_auditoria_valores_nuevos_gin ON portal.auditoria USING gin (valores_nuevos);


--
-- TOC entry 4960 (class 1259 OID 17879)
-- Name: idx_certificados_deudores; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_certificados_deudores ON portal.certificados USING btree (estado_deuda, monto_deuda) WHERE (es_deudor = true);


--
-- TOC entry 4961 (class 1259 OID 17876)
-- Name: idx_certificados_emisor; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_certificados_emisor ON portal.certificados USING btree (empleado_emisor_id) WHERE (empleado_emisor_id IS NOT NULL);


--
-- TOC entry 4962 (class 1259 OID 17875)
-- Name: idx_certificados_numero; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_certificados_numero ON portal.certificados USING btree (numero_certificado);


--
-- TOC entry 4963 (class 1259 OID 17874)
-- Name: idx_certificados_solicitud; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_certificados_solicitud ON portal.certificados USING btree (solicitud_id);


--
-- TOC entry 4964 (class 1259 OID 17877)
-- Name: idx_certificados_vencimiento; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_certificados_vencimiento ON portal.certificados USING btree (fecha_vencimiento);


--
-- TOC entry 4965 (class 1259 OID 17878)
-- Name: idx_certificados_vigentes; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_certificados_vigentes ON portal.certificados USING btree (fecha_vencimiento) WHERE (fecha_vencimiento > '2000-01-01'::date);


--
-- TOC entry 4980 (class 1259 OID 17886)
-- Name: idx_configuracion_clave; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_configuracion_clave ON portal.configuracion USING btree (clave);


--
-- TOC entry 4929 (class 1259 OID 17861)
-- Name: idx_empleados_ciudad; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_empleados_ciudad ON portal.empleados USING btree (ciudad_id) WHERE (ciudad_id IS NOT NULL);


--
-- TOC entry 4930 (class 1259 OID 17855)
-- Name: idx_empleados_email; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_empleados_email ON portal.empleados USING btree (email);


--
-- TOC entry 4931 (class 1259 OID 17856)
-- Name: idx_empleados_estado_activo; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_empleados_estado_activo ON portal.empleados USING btree (estado) WHERE (estado = 'activo'::portal.estado_empleado_t);


--
-- TOC entry 4985 (class 1259 OID 17888)
-- Name: idx_otp_activos; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_otp_activos ON portal.otp_sessions USING btree (email, expira_at) WHERE (usado = false);


--
-- TOC entry 4986 (class 1259 OID 17887)
-- Name: idx_otp_email_cuit; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_otp_email_cuit ON portal.otp_sessions USING btree (email, cuit_dni);


--
-- TOC entry 4987 (class 1259 OID 17889)
-- Name: idx_otp_expira_at; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_otp_expira_at ON portal.otp_sessions USING btree (expira_at) WHERE (usado = false);


--
-- TOC entry 4936 (class 1259 OID 17869)
-- Name: idx_solicitudes_activas; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_activas ON portal.solicitudes USING btree (estado, prioridad, fecha_solicitud DESC) WHERE (estado <> ALL (ARRAY['cancelada'::portal.estado_solicitud_t, 'rechazada'::portal.estado_solicitud_t, 'certificado_emitido'::portal.estado_solicitud_t]));


--
-- TOC entry 4937 (class 1259 OID 17858)
-- Name: idx_solicitudes_ciudad; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_ciudad ON portal.solicitudes USING btree (ciudad_id);


--
-- TOC entry 4938 (class 1259 OID 17859)
-- Name: idx_solicitudes_ciudad_estado; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_ciudad_estado ON portal.solicitudes USING btree (ciudad_id, estado);


--
-- TOC entry 4939 (class 1259 OID 17860)
-- Name: idx_solicitudes_ciudad_fecha; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_ciudad_fecha ON portal.solicitudes USING btree (ciudad_id, fecha_solicitud DESC);


--
-- TOC entry 4940 (class 1259 OID 17866)
-- Name: idx_solicitudes_cuit_dni; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_cuit_dni ON portal.solicitudes USING btree (cuit_dni);


--
-- TOC entry 4941 (class 1259 OID 17865)
-- Name: idx_solicitudes_email; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_email ON portal.solicitudes USING btree (email);


--
-- TOC entry 4942 (class 1259 OID 17862)
-- Name: idx_solicitudes_empleado; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_empleado ON portal.solicitudes USING btree (empleado_asignado_id) WHERE (empleado_asignado_id IS NOT NULL);


--
-- TOC entry 4943 (class 1259 OID 17857)
-- Name: idx_solicitudes_estado; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_estado ON portal.solicitudes USING btree (estado);


--
-- TOC entry 4944 (class 1259 OID 17863)
-- Name: idx_solicitudes_fecha; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_fecha ON portal.solicitudes USING btree (fecha_solicitud DESC);


--
-- TOC entry 4945 (class 1259 OID 17868)
-- Name: idx_solicitudes_kanban; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_kanban ON portal.solicitudes USING btree (estado, prioridad, fecha_solicitud DESC) WHERE (estado = ANY (ARRAY['pagada'::portal.estado_solicitud_t, 'en_revision'::portal.estado_solicitud_t, 'certificado_emitido'::portal.estado_solicitud_t]));


--
-- TOC entry 4946 (class 1259 OID 17867)
-- Name: idx_solicitudes_numero; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_numero ON portal.solicitudes USING btree (numero_solicitud);


--
-- TOC entry 4947 (class 1259 OID 17864)
-- Name: idx_solicitudes_prioridad_urgente; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_solicitudes_prioridad_urgente ON portal.solicitudes USING btree (prioridad) WHERE (prioridad = 'urgente'::portal.prioridad_t);


--
-- TOC entry 4952 (class 1259 OID 17871)
-- Name: idx_transacciones_estado; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_transacciones_estado ON portal.transacciones USING btree (estado);


--
-- TOC entry 4953 (class 1259 OID 17873)
-- Name: idx_transacciones_fecha; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_transacciones_fecha ON portal.transacciones USING btree (fecha_transaccion DESC);


--
-- TOC entry 4954 (class 1259 OID 17872)
-- Name: idx_transacciones_referencia; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_transacciones_referencia ON portal.transacciones USING btree (referencia_pluspagos) WHERE (referencia_pluspagos IS NOT NULL);


--
-- TOC entry 4955 (class 1259 OID 17870)
-- Name: idx_transacciones_solicitud; Type: INDEX; Schema: portal; Owner: postgres
--

CREATE INDEX idx_transacciones_solicitud ON portal.transacciones USING btree (solicitud_id);


--
-- TOC entry 5004 (class 2620 OID 17853)
-- Name: certificados trg_auditoria_certificados; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_auditoria_certificados AFTER INSERT OR DELETE OR UPDATE ON portal.certificados FOR EACH ROW EXECUTE FUNCTION portal.fn_registrar_auditoria();


--
-- TOC entry 4998 (class 2620 OID 17852)
-- Name: empleados trg_auditoria_empleados; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_auditoria_empleados AFTER INSERT OR DELETE OR UPDATE ON portal.empleados FOR EACH ROW EXECUTE FUNCTION portal.fn_registrar_auditoria();


--
-- TOC entry 5006 (class 2620 OID 17854)
-- Name: auditoria trg_auditoria_immutable; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_auditoria_immutable BEFORE DELETE OR UPDATE ON portal.auditoria FOR EACH ROW EXECUTE FUNCTION portal.fn_prevent_auditoria_mod();


--
-- TOC entry 5000 (class 2620 OID 17851)
-- Name: solicitudes trg_auditoria_solicitudes; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_auditoria_solicitudes AFTER INSERT OR DELETE OR UPDATE ON portal.solicitudes FOR EACH ROW EXECUTE FUNCTION portal.fn_registrar_auditoria();


--
-- TOC entry 5007 (class 2620 OID 17847)
-- Name: configuracion trg_configuracion_updated_at; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_configuracion_updated_at BEFORE UPDATE ON portal.configuracion FOR EACH ROW EXECUTE FUNCTION portal.fn_set_updated_at();


--
-- TOC entry 4999 (class 2620 OID 17908)
-- Name: empleados trg_empleados_updated_at; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_empleados_updated_at BEFORE UPDATE ON portal.empleados FOR EACH ROW EXECUTE FUNCTION portal.fn_set_fecha_actualizacion();


--
-- TOC entry 5005 (class 2620 OID 17850)
-- Name: certificados trg_generar_numero_certificado; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_generar_numero_certificado BEFORE INSERT ON portal.certificados FOR EACH ROW EXECUTE FUNCTION portal.fn_generar_numero_certificado();


--
-- TOC entry 5001 (class 2620 OID 17848)
-- Name: solicitudes trg_generar_numero_solicitud; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_generar_numero_solicitud BEFORE INSERT ON portal.solicitudes FOR EACH ROW EXECUTE FUNCTION portal.fn_generar_numero_solicitud();


--
-- TOC entry 5002 (class 2620 OID 17849)
-- Name: solicitudes trg_solicitud_timestamps_estado; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_solicitud_timestamps_estado BEFORE UPDATE OF estado ON portal.solicitudes FOR EACH ROW EXECUTE FUNCTION portal.fn_solicitud_timestamps_estado();


--
-- TOC entry 5003 (class 2620 OID 17846)
-- Name: solicitudes trg_solicitudes_updated_at; Type: TRIGGER; Schema: portal; Owner: postgres
--

CREATE TRIGGER trg_solicitudes_updated_at BEFORE UPDATE ON portal.solicitudes FOR EACH ROW EXECUTE FUNCTION portal.fn_set_updated_at();


--
-- TOC entry 4996 (class 2606 OID 17794)
-- Name: auditoria fk_auditoria_usuario; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.auditoria
    ADD CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES portal.empleados(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4994 (class 2606 OID 17775)
-- Name: certificados fk_certificados_empleado; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.certificados
    ADD CONSTRAINT fk_certificados_empleado FOREIGN KEY (empleado_emisor_id) REFERENCES portal.empleados(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4995 (class 2606 OID 17770)
-- Name: certificados fk_certificados_solicitud; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.certificados
    ADD CONSTRAINT fk_certificados_solicitud FOREIGN KEY (solicitud_id) REFERENCES portal.solicitudes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4997 (class 2606 OID 17818)
-- Name: configuracion fk_configuracion_updated_by; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.configuracion
    ADD CONSTRAINT fk_configuracion_updated_by FOREIGN KEY (updated_by) REFERENCES portal.empleados(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4990 (class 2606 OID 17671)
-- Name: empleados fk_empleados_ciudad; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.empleados
    ADD CONSTRAINT fk_empleados_ciudad FOREIGN KEY (ciudad_id) REFERENCES portal.ciudades(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4991 (class 2606 OID 17705)
-- Name: solicitudes fk_solicitudes_ciudad; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.solicitudes
    ADD CONSTRAINT fk_solicitudes_ciudad FOREIGN KEY (ciudad_id) REFERENCES portal.ciudades(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- TOC entry 4992 (class 2606 OID 17710)
-- Name: solicitudes fk_solicitudes_empleado; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.solicitudes
    ADD CONSTRAINT fk_solicitudes_empleado FOREIGN KEY (empleado_asignado_id) REFERENCES portal.empleados(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- TOC entry 4993 (class 2606 OID 17737)
-- Name: transacciones fk_transacciones_solicitud; Type: FK CONSTRAINT; Schema: portal; Owner: postgres
--

ALTER TABLE ONLY portal.transacciones
    ADD CONSTRAINT fk_transacciones_solicitud FOREIGN KEY (solicitud_id) REFERENCES portal.solicitudes(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 5179 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA portal; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA portal TO portal_app;
GRANT USAGE ON SCHEMA portal TO portal_readonly;


--
-- TOC entry 5180 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE auditoria; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT ON TABLE portal.auditoria TO portal_app;
GRANT SELECT ON TABLE portal.auditoria TO portal_readonly;


--
-- TOC entry 5181 (class 0 OID 0)
-- Dependencies: 233
-- Name: SEQUENCE auditoria_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.auditoria_id_seq TO portal_app;


--
-- TOC entry 5182 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE certificados; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.certificados TO portal_app;
GRANT SELECT ON TABLE portal.certificados TO portal_readonly;


--
-- TOC entry 5183 (class 0 OID 0)
-- Dependencies: 231
-- Name: SEQUENCE certificados_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.certificados_id_seq TO portal_app;


--
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE ciudades; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.ciudades TO portal_app;
GRANT SELECT ON TABLE portal.ciudades TO portal_readonly;


--
-- TOC entry 5185 (class 0 OID 0)
-- Dependencies: 223
-- Name: SEQUENCE ciudades_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.ciudades_id_seq TO portal_app;


--
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE configuracion; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.configuracion TO portal_app;
GRANT SELECT ON TABLE portal.configuracion TO portal_readonly;


--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 235
-- Name: SEQUENCE configuracion_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.configuracion_id_seq TO portal_app;


--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE empleados; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.empleados TO portal_app;
GRANT SELECT ON TABLE portal.empleados TO portal_readonly;


--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 225
-- Name: SEQUENCE empleados_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.empleados_id_seq TO portal_app;


--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 238
-- Name: TABLE otp_sessions; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.otp_sessions TO portal_app;
GRANT SELECT ON TABLE portal.otp_sessions TO portal_readonly;


--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 237
-- Name: SEQUENCE otp_sessions_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.otp_sessions_id_seq TO portal_app;


--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 222
-- Name: SEQUENCE seq_numero_certificado; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.seq_numero_certificado TO portal_app;


--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE solicitudes; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.solicitudes TO portal_app;
GRANT SELECT ON TABLE portal.solicitudes TO portal_readonly;


--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE solicitudes_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.solicitudes_id_seq TO portal_app;


--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE transacciones; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.transacciones TO portal_app;
GRANT SELECT ON TABLE portal.transacciones TO portal_readonly;


--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 229
-- Name: SEQUENCE transacciones_id_seq; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE portal.transacciones_id_seq TO portal_app;


--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 240
-- Name: TABLE v_kpis_dashboard; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.v_kpis_dashboard TO portal_app;
GRANT SELECT ON TABLE portal.v_kpis_dashboard TO portal_readonly;


--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE v_solicitudes_completas; Type: ACL; Schema: portal; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE portal.v_solicitudes_completas TO portal_app;
GRANT SELECT ON TABLE portal.v_solicitudes_completas TO portal_readonly;


--
-- TOC entry 2180 (class 826 OID 17905)
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: portal; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA portal GRANT SELECT,INSERT,UPDATE ON TABLES TO portal_app;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA portal GRANT SELECT ON TABLES TO portal_readonly;


-- Completed on 2026-03-06 19:46:47

--
-- PostgreSQL database dump complete
--

\unrestrict cvkEyAmXDzoyEKKBaWDPbvJyNdqL29dCYh1zMgsqXNqvD9Gg3H7NZZO3aM5FB1y

