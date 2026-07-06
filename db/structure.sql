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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    membership_id uuid NOT NULL,
    token character varying,
    description character varying,
    last_used_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: account_zone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_zone (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    provincia character varying NOT NULL,
    grado character varying NOT NULL,
    anno_scolastico character varying,
    regione character varying,
    scuole_count integer DEFAULT 0,
    stato character varying DEFAULT 'attiva'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    slug character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    adozioni_aggiornamento_started_at timestamp(6) without time zone,
    adozioni_aggiornate_at timestamp(6) without time zone
);


--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    body text,
    record_type character varying NOT NULL,
    record_id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_text_rich_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_text_rich_texts_id_seq OWNED BY public.action_text_rich_texts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id character varying NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: adozioni; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adozioni (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    classe_id uuid NOT NULL,
    libro_id bigint,
    import_adozione_id bigint,
    codice_isbn character varying,
    titolo character varying,
    editore character varying,
    autori character varying,
    disciplina character varying,
    prezzo_cents integer DEFAULT 0,
    nuova_adozione boolean DEFAULT false,
    da_acquistare boolean DEFAULT false,
    consigliato boolean DEFAULT false,
    numero_copie integer DEFAULT 0,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    mia boolean DEFAULT false NOT NULL,
    disdetta boolean DEFAULT false NOT NULL,
    anno_scolastico character varying,
    codicescuola character varying,
    anno_corso character varying
);


--
-- Name: adozioni_comunicate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adozioni_comunicate (
    id bigint NOT NULL,
    cod_agente character varying,
    anno_scolastico character varying,
    cod_ministeriale character varying,
    descrizione_scuola character varying,
    indirizzo character varying,
    cap character varying,
    comune character varying,
    provincia character varying,
    cod_scuola character varying,
    editore character varying,
    ean character varying,
    titolo character varying,
    classe character varying,
    sezione character varying,
    alunni integer,
    codice_scuola_match character varying,
    codice_isbn_match character varying,
    anno_corso_match character varying,
    sezione_anno_match character varying,
    user_id bigint NOT NULL,
    import_adozione_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    da_acquistare character varying
);


--
-- Name: adozioni_comunicate_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.adozioni_comunicate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adozioni_comunicate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.adozioni_comunicate_id_seq OWNED BY public.adozioni_comunicate.id;


--
-- Name: ahoy_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ahoy_events (
    id bigint NOT NULL,
    visit_id bigint,
    user_id bigint,
    name character varying,
    properties jsonb,
    "time" timestamp(6) without time zone
);


--
-- Name: ahoy_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ahoy_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ahoy_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ahoy_events_id_seq OWNED BY public.ahoy_events.id;


--
-- Name: ahoy_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ahoy_visits (
    id bigint NOT NULL,
    visit_token character varying,
    visitor_token character varying,
    user_id bigint,
    ip character varying,
    user_agent text,
    referrer text,
    referring_domain character varying,
    landing_page text,
    browser character varying,
    os character varying,
    device_type character varying,
    country character varying,
    region character varying,
    city character varying,
    latitude double precision,
    longitude double precision,
    utm_source character varying,
    utm_medium character varying,
    utm_term character varying,
    utm_content character varying,
    utm_campaign character varying,
    app_version character varying,
    os_version character varying,
    platform character varying,
    started_at timestamp(6) without time zone
);


--
-- Name: ahoy_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ahoy_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ahoy_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ahoy_visits_id_seq OWNED BY public.ahoy_visits.id;


--
-- Name: appunti; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appunti (
    user_id bigint NOT NULL,
    nome character varying,
    body text,
    email character varying,
    telefono character varying,
    stato character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    team character varying,
    voice_note_id bigint,
    active boolean,
    account_id uuid,
    appuntabile_type character varying,
    appuntabile_id uuid,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    numero integer,
    status character varying DEFAULT 'drafted'::character varying NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: aziende; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aziende (
    id bigint NOT NULL,
    user_id bigint,
    partita_iva character varying(11) NOT NULL,
    codice_fiscale character varying(16) NOT NULL,
    ragione_sociale character varying NOT NULL,
    regime_fiscale character varying DEFAULT 'RF19'::character varying NOT NULL,
    indirizzo character varying NOT NULL,
    cap character varying(5) NOT NULL,
    comune character varying NOT NULL,
    provincia character varying(2) NOT NULL,
    nazione character varying(2) DEFAULT 'IT'::character varying NOT NULL,
    email character varying NOT NULL,
    telefono character varying,
    indirizzo_telematico character varying(7),
    iban character varying(27),
    banca character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    account_id uuid NOT NULL,
    sconto_defiscalizzato boolean DEFAULT false NOT NULL,
    codice_intermediario character varying DEFAULT '01879020517'::character varying
);


--
-- Name: aziende_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.aziende_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aziende_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.aziende_id_seq OWNED BY public.aziende.id;


--
-- Name: blazer_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_audits (
    id bigint NOT NULL,
    user_id bigint,
    query_id bigint,
    statement text,
    data_source character varying,
    created_at timestamp(6) without time zone
);


--
-- Name: blazer_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_audits_id_seq OWNED BY public.blazer_audits.id;


--
-- Name: blazer_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_checks (
    id bigint NOT NULL,
    creator_id bigint,
    query_id bigint,
    state character varying,
    schedule character varying,
    emails text,
    slack_channels text,
    check_type character varying,
    message text,
    last_run_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_checks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_checks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_checks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_checks_id_seq OWNED BY public.blazer_checks.id;


--
-- Name: blazer_dashboard_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_dashboard_queries (
    id bigint NOT NULL,
    dashboard_id bigint,
    query_id bigint,
    "position" integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_dashboard_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_dashboard_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_dashboard_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_dashboard_queries_id_seq OWNED BY public.blazer_dashboard_queries.id;


--
-- Name: blazer_dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_dashboards (
    id bigint NOT NULL,
    creator_id bigint,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_dashboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_dashboards_id_seq OWNED BY public.blazer_dashboards.id;


--
-- Name: blazer_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blazer_queries (
    id bigint NOT NULL,
    creator_id bigint,
    name character varying,
    description text,
    statement text,
    data_source character varying,
    status character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blazer_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blazer_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blazer_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blazer_queries_id_seq OWNED BY public.blazer_queries.id;


--
-- Name: bolla_visione_righe; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bolla_visione_righe (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    bolla_visione_id uuid NOT NULL,
    libro_id bigint NOT NULL,
    quantita integer DEFAULT 1 NOT NULL,
    classi_target character varying,
    "position" integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    consegna jsonb DEFAULT '{}'::jsonb,
    esito integer,
    processato_at timestamp(6) without time zone,
    documento_riga_id bigint
);


--
-- Name: bolle_visione; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bolle_visione (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    user_id bigint NOT NULL,
    numero integer NOT NULL,
    data_bolla date NOT NULL,
    collana_id uuid NOT NULL,
    scuola_id uuid NOT NULL,
    tappa_id uuid,
    contatto_id uuid,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categorie; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categorie (
    id bigint NOT NULL,
    nome_categoria character varying NOT NULL,
    descrizione text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint,
    account_id uuid NOT NULL
);


--
-- Name: categorie_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categorie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categorie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categorie_id_seq OWNED BY public.categorie.id;


--
-- Name: cattedra_discipline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cattedra_discipline (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cattedra character varying NOT NULL,
    disciplina character varying NOT NULL,
    tipo_scuola character varying NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: causali; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.causali (
    id bigint NOT NULL,
    causale character varying,
    magazzino character varying,
    tipo_movimento integer,
    movimento integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    clientable_type character varying,
    stato_iniziale character varying,
    stati_successivi json DEFAULT '[]'::json,
    priorita integer DEFAULT 0,
    causali_successive json DEFAULT '[]'::json
);


--
-- Name: causali_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.causali_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: causali_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.causali_id_seq OWNED BY public.causali.id;


--
-- Name: chats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chats (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    model_id bigint,
    account_id uuid NOT NULL
);


--
-- Name: chats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chats_id_seq OWNED BY public.chats.id;


--
-- Name: classi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    scuola_id uuid NOT NULL,
    anno_corso character varying,
    sezione character varying,
    combinazione character varying,
    tipo_scuola character varying,
    codice_ministeriale_origine character varying,
    classe_origine character varying,
    sezione_origine character varying,
    combinazione_origine character varying,
    note text,
    numero_alunni integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    anno_scolastico character varying,
    stato character varying DEFAULT 'attiva'::character varying NOT NULL
);


--
-- Name: clienti; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clienti (
    codice_cliente character varying,
    tipo_cliente character varying,
    indirizzo_telematico character varying,
    email character varying,
    pec character varying,
    telefono character varying,
    id_paese character varying,
    partita_iva character varying,
    codice_fiscale character varying,
    denominazione character varying,
    nome character varying,
    cognome character varying,
    codice_eori character varying,
    nazione character varying,
    cap character varying,
    provincia character varying,
    comune character varying,
    indirizzo character varying,
    numero_civico character varying,
    beneficiario character varying,
    condizioni_di_pagamento character varying,
    metodo_di_pagamento character varying,
    banca character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint,
    slug character varying,
    latitude double precision,
    longitude double precision,
    geocoded boolean,
    account_id uuid NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.closures (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    closeable_type character varying,
    closeable_id character varying,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    entry_id uuid
);


--
-- Name: collana_libri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collana_libri (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    collana_id uuid NOT NULL,
    libro_id bigint NOT NULL,
    classi_target character varying,
    "position" integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    gruppo character varying
);


--
-- Name: collane; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.collane (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    user_id bigint NOT NULL,
    nome character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.columns (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    color character varying DEFAULT 'var(--color-card-default)'::character varying,
    "position" integer DEFAULT 0,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: confezione_righe; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.confezione_righe (
    id bigint NOT NULL,
    confezione_id bigint,
    fascicolo_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    row_order integer
);


--
-- Name: confezione_righe_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.confezione_righe_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: confezione_righe_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.confezione_righe_id_seq OWNED BY public.confezione_righe.id;


--
-- Name: consegne; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consegne (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    consegnabile_type character varying NOT NULL,
    consegnabile_id uuid NOT NULL,
    user_id bigint,
    consegnato_il timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: consegne_saggio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consegne_saggio (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    user_id bigint NOT NULL,
    adozione_id uuid NOT NULL,
    tipo character varying NOT NULL,
    libro_id bigint,
    quantita integer DEFAULT 1 NOT NULL,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: controllo_anomalie; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.controllo_anomalie (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    anno_scolastico character varying,
    codicescuola character varying NOT NULL,
    annocorso character varying,
    sezioneanno character varying,
    combinazione character varying,
    regione character varying,
    provincia character varying,
    comune character varying,
    denominazione character varying,
    tipo character varying NOT NULL,
    disciplina character varying,
    codiceisbn character varying,
    titolo character varying,
    editore character varying,
    prezzo_cents integer,
    prezzo_atteso_cents integer,
    delta_cents integer,
    dettaglio jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: disponibilita; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disponibilita (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scuola_id uuid NOT NULL,
    account_id uuid NOT NULL,
    user_id bigint,
    tipo character varying NOT NULL,
    giorno_settimana integer,
    data date,
    ora_inizio time without time zone,
    ora_fine time without time zone,
    titolo character varying,
    ricorrente boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: documenti; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documenti (
    numero_documento integer,
    user_id bigint NOT NULL,
    data_documento date,
    causale_id bigint,
    tipo_pagamento integer,
    consegnato_il date,
    status integer,
    iva_cents bigint,
    totale_cents bigint,
    spese_cents bigint,
    totale_copie integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    clientable_type character varying,
    tipo_documento integer,
    note text,
    referente text,
    pagato_il timestamp(6) without time zone,
    derivato_da_causale_id integer,
    account_id uuid NOT NULL,
    clientable_id uuid,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    documento_padre_id uuid
);


--
-- Name: documento_righe; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documento_righe (
    id bigint NOT NULL,
    riga_id bigint,
    posizione integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    documento_id uuid
);


--
-- Name: documento_righe_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documento_righe_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documento_righe_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documento_righe_id_seq OWNED BY public.documento_righe.id;


--
-- Name: editori; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.editori (
    id bigint NOT NULL,
    editore character varying,
    gruppo character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: editori_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.editori_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: editori_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.editori_id_seq OWNED BY public.editori.id;


--
-- Name: edizioni_titoli; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.edizioni_titoli (
    id bigint NOT NULL,
    codice_isbn character varying,
    titolo_originale character varying,
    autore character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: edizioni_titoli_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.edizioni_titoli_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: edizioni_titoli_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.edizioni_titoli_id_seq OWNED BY public.edizioni_titoli.id;


--
-- Name: entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entryable_type character varying NOT NULL,
    entryable_id character varying NOT NULL,
    column_id uuid,
    giro_id bigint,
    user_id bigint NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entry_id uuid NOT NULL,
    user_id bigint,
    account_id uuid NOT NULL,
    action character varying NOT NULL,
    particulars jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    creator_id bigint,
    account_id uuid,
    fields jsonb DEFAULT '{}'::jsonb,
    params_digest character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    type character varying NOT NULL
);


--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendly_id_slugs (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    sluggable_id integer NOT NULL,
    sluggable_type character varying(50),
    scope character varying,
    created_at timestamp(6) without time zone
);


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendly_id_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendly_id_slugs_id_seq OWNED BY public.friendly_id_slugs.id;


--
-- Name: giri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.giri (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    iniziato_il timestamp(6) without time zone,
    finito_il timestamp(6) without time zone,
    titolo character varying,
    descrizione character varying,
    stato character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    conditions text,
    account_id uuid NOT NULL,
    color character varying DEFAULT 'var(--color-card-default)'::character varying,
    tipo_giro character varying,
    collana_id uuid,
    propaganda_id uuid
);


--
-- Name: giri_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.giri_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: giri_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.giri_id_seq OWNED BY public.giri.id;


--
-- Name: goldnesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goldnesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    goldenable_type character varying,
    goldenable_id uuid,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    entry_id uuid
);


--
-- Name: miur_adozioni; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_adozioni (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    annocorso character varying,
    autori character varying,
    codiceisbn character varying,
    codicescuola character varying,
    combinazione character varying,
    consigliato character varying,
    daacquist character varying,
    disciplina character varying,
    editore character varying,
    nuovaadoz character varying,
    prezzo character varying,
    sezioneanno character varying,
    sottotitolo character varying,
    tipogradoscuola character varying,
    titolo character varying,
    volume character varying,
    import_scuola_id bigint
)
PARTITION BY LIST (anno_scolastico);


--
-- Name: import_adozioni; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.import_adozioni AS
 SELECT miur_adozioni.id,
    miur_adozioni.codicescuola AS "CODICESCUOLA",
    miur_adozioni.annocorso AS "ANNOCORSO",
    miur_adozioni.sezioneanno AS "SEZIONEANNO",
    miur_adozioni.tipogradoscuola AS "TIPOGRADOSCUOLA",
    miur_adozioni.combinazione AS "COMBINAZIONE",
    miur_adozioni.disciplina AS "DISCIPLINA",
    miur_adozioni.codiceisbn AS "CODICEISBN",
    miur_adozioni.autori AS "AUTORI",
    miur_adozioni.titolo AS "TITOLO",
    miur_adozioni.sottotitolo AS "SOTTOTITOLO",
    miur_adozioni.volume AS "VOLUME",
    miur_adozioni.editore AS "EDITORE",
    miur_adozioni.prezzo AS "PREZZO",
    miur_adozioni.nuovaadoz AS "NUOVAADOZ",
    miur_adozioni.daacquist AS "DAACQUIST",
    miur_adozioni.consigliato AS "CONSIGLIATO",
    miur_adozioni.anno_scolastico
   FROM public.miur_adozioni
  WHERE ((miur_adozioni.anno_scolastico)::text = '202526'::text);


--
-- Name: import_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    account_id uuid NOT NULL,
    import_type integer NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    imported_count integer DEFAULT 0,
    updated_count integer DEFAULT 0,
    errors_count integer DEFAULT 0,
    error_messages text[] DEFAULT '{}'::text[],
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: import_scuole; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_scuole (
    id bigint NOT NULL,
    "ANNOSCOLASTICO" character varying,
    "AREAGEOGRAFICA" character varying,
    "REGIONE" character varying,
    "PROVINCIA" character varying,
    "CODICEISTITUTORIFERIMENTO" character varying,
    "DENOMINAZIONEISTITUTORIFERIMENTO" character varying,
    "CODICESCUOLA" character varying,
    "DENOMINAZIONESCUOLA" character varying,
    "INDIRIZZOSCUOLA" character varying,
    "CAPSCUOLA" character varying,
    "CODICECOMUNESCUOLA" character varying,
    "DESCRIZIONECOMUNE" character varying,
    "DESCRIZIONECARATTERISTICASCUOLA" character varying,
    "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" character varying,
    "INDICAZIONESEDEDIRETTIVO" character varying,
    "INDICAZIONESEDEOMNICOMPRENSIVO" character varying,
    "INDIRIZZOEMAILSCUOLA" character varying,
    "INDIRIZZOPECSCUOLA" character varying,
    "SITOWEBSCUOLA" character varying,
    "SEDESCOLASTICA" character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    slug character varying,
    latitude double precision,
    longitude double precision,
    geocoded boolean
);


--
-- Name: import_scuole_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_scuole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_scuole_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_scuole_id_seq OWNED BY public.import_scuole.id;


--
-- Name: imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.imports (
    id bigint NOT NULL,
    fornitore character varying,
    iva_fornitore character varying,
    cliente character varying,
    iva_cliente character varying,
    tipo_documento character varying,
    numero_documento character varying,
    data_documento date,
    totale_documento double precision,
    riga integer,
    codice_articolo character varying,
    descrizione character varying,
    prezzo_unitario double precision,
    quantita integer,
    importo_netto double precision,
    sconto double precision,
    iva integer
);


--
-- Name: imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.imports_id_seq OWNED BY public.imports.id;


--
-- Name: legacy_mandati; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_mandati (
    user_id bigint NOT NULL,
    editore_id bigint NOT NULL,
    contratto text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: libri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.libri (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    editore_id bigint,
    titolo character varying,
    codice_isbn character varying,
    prezzo_in_cents integer,
    classe integer,
    disciplina character varying,
    note text,
    collana character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    numero_fascicoli integer,
    fascicoli_count integer DEFAULT 0 NOT NULL,
    confezioni_count integer DEFAULT 0 NOT NULL,
    adozioni_count integer DEFAULT 0 NOT NULL,
    slug character varying,
    categoria_id bigint NOT NULL,
    prezzo_suggerito_cents integer DEFAULT 0,
    cm character varying,
    account_id uuid NOT NULL
);


--
-- Name: libri_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.libri_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: libri_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.libri_id_seq OWNED BY public.libri.id;


--
-- Name: magic_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.magic_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    code character varying NOT NULL,
    purpose character varying DEFAULT 'sign_in'::character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    used_at timestamp(6) without time zone,
    ip_address character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mandati; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mandati (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    editore_id bigint NOT NULL,
    provincia character varying,
    grado character varying,
    anno_scolastico character varying,
    contratto text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    disdetta boolean DEFAULT false NOT NULL,
    sezioni_count integer DEFAULT 0,
    area character varying
);


--
-- Name: membership_scuole; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_scuole (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    membership_id uuid NOT NULL,
    scuola_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    account_id uuid NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mercato_nazionale_libri; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mercato_nazionale_libri AS
 SELECT adozioni_annate.anno_scolastico,
    adozioni_annate.tipo_grado_scuola,
    adozioni_annate.disciplina,
    adozioni_annate.anno_corso,
    adozioni_annate.codice_isbn,
    count(DISTINCT adozioni_annate.sezione_key) AS sezioni
   FROM ( SELECT miur_adozioni.anno_scolastico,
            miur_adozioni.tipogradoscuola AS tipo_grado_scuola,
            miur_adozioni.disciplina,
            miur_adozioni.annocorso AS anno_corso,
            miur_adozioni.codiceisbn AS codice_isbn,
            (((((miur_adozioni.codicescuola)::text || '_'::text) || (miur_adozioni.annocorso)::text) || '_'::text) || (miur_adozioni.sezioneanno)::text) AS sezione_key
           FROM public.miur_adozioni
          WHERE ((miur_adozioni.daacquist)::text = 'Si'::text)) adozioni_annate
  GROUP BY adozioni_annate.anno_scolastico, adozioni_annate.tipo_grado_scuola, adozioni_annate.disciplina, adozioni_annate.anno_corso, adozioni_annate.codice_isbn
  WITH NO DATA;


--
-- Name: mercato_nazionale_mercati; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mercato_nazionale_mercati AS
 SELECT adozioni_annate.anno_scolastico,
    adozioni_annate.tipo_grado_scuola,
    adozioni_annate.disciplina,
    adozioni_annate.anno_corso,
    count(DISTINCT adozioni_annate.sezione_key) AS sezioni
   FROM ( SELECT miur_adozioni.anno_scolastico,
            miur_adozioni.tipogradoscuola AS tipo_grado_scuola,
            miur_adozioni.disciplina,
            miur_adozioni.annocorso AS anno_corso,
            (((((miur_adozioni.codicescuola)::text || '_'::text) || (miur_adozioni.annocorso)::text) || '_'::text) || (miur_adozioni.sezioneanno)::text) AS sezione_key
           FROM public.miur_adozioni
          WHERE ((miur_adozioni.daacquist)::text = 'Si'::text)) adozioni_annate
  GROUP BY adozioni_annate.anno_scolastico, adozioni_annate.tipo_grado_scuola, adozioni_annate.disciplina, adozioni_annate.anno_corso
  WITH NO DATA;


--
-- Name: mercato_scuola_mercati; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.mercato_scuola_mercati AS
 SELECT adozioni_annate.anno_scolastico,
    adozioni_annate.codice_scuola,
    adozioni_annate.tipo_grado_scuola,
    adozioni_annate.disciplina,
    adozioni_annate.anno_corso,
    count(DISTINCT adozioni_annate.sezione) AS sezioni
   FROM ( SELECT miur_adozioni.anno_scolastico,
            miur_adozioni.codicescuola AS codice_scuola,
            miur_adozioni.tipogradoscuola AS tipo_grado_scuola,
            miur_adozioni.disciplina,
            miur_adozioni.annocorso AS anno_corso,
            miur_adozioni.sezioneanno AS sezione
           FROM public.miur_adozioni
          WHERE ((miur_adozioni.daacquist)::text = 'Si'::text)) adozioni_annate
  GROUP BY adozioni_annate.anno_scolastico, adozioni_annate.codice_scuola, adozioni_annate.tipo_grado_scuola, adozioni_annate.disciplina, adozioni_annate.anno_corso
  WITH NO DATA;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    chat_id bigint,
    role character varying DEFAULT 0 NOT NULL,
    content text,
    response_number integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    input_tokens integer,
    output_tokens integer,
    model_id bigint,
    tool_call_id bigint
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: miur_adozioni_202425; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_adozioni_202425 (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    annocorso character varying,
    autori character varying,
    codiceisbn character varying,
    codicescuola character varying,
    combinazione character varying,
    consigliato character varying,
    daacquist character varying,
    disciplina character varying,
    editore character varying,
    nuovaadoz character varying,
    prezzo character varying,
    sezioneanno character varying,
    sottotitolo character varying,
    tipogradoscuola character varying,
    titolo character varying,
    volume character varying,
    import_scuola_id bigint
);


--
-- Name: miur_adozioni_202526; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_adozioni_202526 (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    annocorso character varying,
    autori character varying,
    codiceisbn character varying,
    codicescuola character varying,
    combinazione character varying,
    consigliato character varying,
    daacquist character varying,
    disciplina character varying,
    editore character varying,
    nuovaadoz character varying,
    prezzo character varying,
    sezioneanno character varying,
    sottotitolo character varying,
    tipogradoscuola character varying,
    titolo character varying,
    volume character varying,
    import_scuola_id bigint
);


--
-- Name: miur_adozioni_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.miur_adozioni ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.miur_adozioni_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: miur_adozioni_202627; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_adozioni_202627 (
    id bigint DEFAULT nextval('public.miur_adozioni_id_seq'::regclass) NOT NULL,
    anno_scolastico character varying NOT NULL,
    annocorso character varying,
    autori character varying,
    codiceisbn character varying,
    codicescuola character varying,
    combinazione character varying,
    consigliato character varying,
    daacquist character varying,
    disciplina character varying,
    editore character varying,
    nuovaadoz character varying,
    prezzo character varying,
    sezioneanno character varying,
    sottotitolo character varying,
    tipogradoscuola character varying,
    titolo character varying,
    volume character varying,
    import_scuola_id bigint
);


--
-- Name: miur_import_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_import_runs (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    dataset character varying DEFAULT 'adozioni'::character varying NOT NULL,
    righe_totali integer,
    delta_righe integer,
    regioni_aggiornate jsonb DEFAULT '[]'::jsonb NOT NULL,
    regioni_stale jsonb DEFAULT '[]'::jsonb NOT NULL,
    regioni_fallite jsonb DEFAULT '[]'::jsonb NOT NULL,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: miur_import_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.miur_import_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: miur_import_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.miur_import_runs_id_seq OWNED BY public.miur_import_runs.id;


--
-- Name: miur_scuole; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_scuole (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    area_geografica character varying,
    cap character varying,
    codice_comune character varying,
    codice_istituto_riferimento character varying,
    codice_scuola character varying,
    comune character varying,
    denominazione character varying,
    denominazione_istituto_riferimento character varying,
    descrizione_caratteristica character varying,
    email character varying,
    indicazione_sede_direttivo character varying,
    indicazione_sede_omnicomprensivo character varying,
    indirizzo character varying,
    pec character varying,
    provincia character varying,
    regione character varying,
    sede_scolastica character varying,
    sito_web character varying,
    tipo_scuola character varying,
    import_scuola_id bigint
)
PARTITION BY LIST (anno_scolastico);


--
-- Name: miur_scuole_202425; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_scuole_202425 (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    area_geografica character varying,
    cap character varying,
    codice_comune character varying,
    codice_istituto_riferimento character varying,
    codice_scuola character varying,
    comune character varying,
    denominazione character varying,
    denominazione_istituto_riferimento character varying,
    descrizione_caratteristica character varying,
    email character varying,
    indicazione_sede_direttivo character varying,
    indicazione_sede_omnicomprensivo character varying,
    indirizzo character varying,
    pec character varying,
    provincia character varying,
    regione character varying,
    sede_scolastica character varying,
    sito_web character varying,
    tipo_scuola character varying,
    import_scuola_id bigint
);


--
-- Name: miur_scuole_202526; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_scuole_202526 (
    id bigint NOT NULL,
    anno_scolastico character varying NOT NULL,
    area_geografica character varying,
    cap character varying,
    codice_comune character varying,
    codice_istituto_riferimento character varying,
    codice_scuola character varying,
    comune character varying,
    denominazione character varying,
    denominazione_istituto_riferimento character varying,
    descrizione_caratteristica character varying,
    email character varying,
    indicazione_sede_direttivo character varying,
    indicazione_sede_omnicomprensivo character varying,
    indirizzo character varying,
    pec character varying,
    provincia character varying,
    regione character varying,
    sede_scolastica character varying,
    sito_web character varying,
    tipo_scuola character varying,
    import_scuola_id bigint
);


--
-- Name: miur_scuole_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.miur_scuole ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.miur_scuole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: miur_scuole_202627; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.miur_scuole_202627 (
    id bigint DEFAULT nextval('public.miur_scuole_id_seq'::regclass) NOT NULL,
    anno_scolastico character varying NOT NULL,
    area_geografica character varying,
    cap character varying,
    codice_comune character varying,
    codice_istituto_riferimento character varying,
    codice_scuola character varying,
    comune character varying,
    denominazione character varying,
    denominazione_istituto_riferimento character varying,
    descrizione_caratteristica character varying,
    email character varying,
    indicazione_sede_direttivo character varying,
    indicazione_sede_omnicomprensivo character varying,
    indirizzo character varying,
    pec character varying,
    provincia character varying,
    regione character varying,
    sede_scolastica character varying,
    sito_web character varying,
    tipo_scuola character varying,
    import_scuola_id bigint
);


--
-- Name: models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.models (
    id bigint NOT NULL,
    model_id character varying NOT NULL,
    name character varying NOT NULL,
    provider character varying NOT NULL,
    family character varying,
    model_created_at timestamp(6) without time zone,
    context_window integer,
    max_output_tokens integer,
    knowledge_cutoff date,
    modalities jsonb DEFAULT '{}'::jsonb,
    capabilities jsonb DEFAULT '[]'::jsonb,
    pricing jsonb DEFAULT '{}'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.models_id_seq OWNED BY public.models.id;


--
-- Name: motor_alert_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_alert_locks (
    id bigint NOT NULL,
    alert_id bigint NOT NULL,
    lock_timestamp character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_alert_locks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_alert_locks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_alert_locks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_alert_locks_id_seq OWNED BY public.motor_alert_locks.id;


--
-- Name: motor_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_alerts (
    id bigint NOT NULL,
    query_id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    to_emails text NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    preferences text NOT NULL,
    author_id bigint,
    author_type character varying,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_alerts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_alerts_id_seq OWNED BY public.motor_alerts.id;


--
-- Name: motor_api_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_api_configs (
    id bigint NOT NULL,
    name character varying NOT NULL,
    url character varying NOT NULL,
    preferences text NOT NULL,
    credentials text NOT NULL,
    description text,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_api_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_api_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_api_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_api_configs_id_seq OWNED BY public.motor_api_configs.id;


--
-- Name: motor_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_audits (
    id bigint NOT NULL,
    auditable_id character varying,
    auditable_type character varying,
    associated_id character varying,
    associated_type character varying,
    user_id bigint,
    user_type character varying,
    username character varying,
    action character varying,
    audited_changes text,
    version bigint DEFAULT 0,
    comment text,
    remote_address character varying,
    request_uuid character varying,
    created_at timestamp(6) without time zone
);


--
-- Name: motor_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_audits_id_seq OWNED BY public.motor_audits.id;


--
-- Name: motor_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_configs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_configs_id_seq OWNED BY public.motor_configs.id;


--
-- Name: motor_dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_dashboards (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    preferences text NOT NULL,
    author_id bigint,
    author_type character varying,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_dashboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_dashboards_id_seq OWNED BY public.motor_dashboards.id;


--
-- Name: motor_forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_forms (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    api_path text NOT NULL,
    http_method character varying NOT NULL,
    preferences text NOT NULL,
    author_id bigint,
    author_type character varying,
    deleted_at timestamp(6) without time zone,
    api_config_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_forms_id_seq OWNED BY public.motor_forms.id;


--
-- Name: motor_note_tag_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_note_tag_tags (
    id bigint NOT NULL,
    tag_id bigint NOT NULL,
    note_id bigint NOT NULL
);


--
-- Name: motor_note_tag_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_note_tag_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_note_tag_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_note_tag_tags_id_seq OWNED BY public.motor_note_tag_tags.id;


--
-- Name: motor_note_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_note_tags (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_note_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_note_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_note_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_note_tags_id_seq OWNED BY public.motor_note_tags.id;


--
-- Name: motor_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_notes (
    id bigint NOT NULL,
    body text,
    author_id bigint,
    author_type character varying,
    record_id character varying NOT NULL,
    record_type character varying NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_notes_id_seq OWNED BY public.motor_notes.id;


--
-- Name: motor_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_notifications (
    id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    recipient_id bigint NOT NULL,
    recipient_type character varying NOT NULL,
    record_id character varying,
    record_type character varying,
    status character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_notifications_id_seq OWNED BY public.motor_notifications.id;


--
-- Name: motor_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_queries (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    sql_body text NOT NULL,
    preferences text NOT NULL,
    author_id bigint,
    author_type character varying,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_queries_id_seq OWNED BY public.motor_queries.id;


--
-- Name: motor_reminders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_reminders (
    id bigint NOT NULL,
    author_id bigint NOT NULL,
    author_type character varying NOT NULL,
    recipient_id bigint NOT NULL,
    recipient_type character varying NOT NULL,
    record_id character varying,
    record_type character varying,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_reminders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_reminders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_reminders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_reminders_id_seq OWNED BY public.motor_reminders.id;


--
-- Name: motor_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_resources (
    id bigint NOT NULL,
    name character varying NOT NULL,
    preferences text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_resources_id_seq OWNED BY public.motor_resources.id;


--
-- Name: motor_taggable_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_taggable_tags (
    id bigint NOT NULL,
    tag_id bigint NOT NULL,
    taggable_id bigint NOT NULL,
    taggable_type character varying NOT NULL
);


--
-- Name: motor_taggable_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_taggable_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_taggable_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_taggable_tags_id_seq OWNED BY public.motor_taggable_tags.id;


--
-- Name: motor_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.motor_tags (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: motor_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.motor_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: motor_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.motor_tags_id_seq OWNED BY public.motor_tags.id;


--
-- Name: not_nows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.not_nows (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    not_nowable_type character varying,
    not_nowable_id uuid,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    entry_id uuid
);


--
-- Name: pagamenti; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pagamenti (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    pagabile_type character varying NOT NULL,
    pagabile_id uuid NOT NULL,
    user_id bigint,
    pagato_il timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tipo_pagamento character varying
);


--
-- Name: persona_classi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persona_classi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    persona_id uuid NOT NULL,
    classe_id uuid NOT NULL,
    materia character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: personal_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personal_infos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    nome character varying,
    cognome character varying,
    cellulare character varying,
    email_personale character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    navigator character varying
);


--
-- Name: persone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.persone (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    scuola_id uuid,
    nome character varying,
    cognome character varying,
    ruolo character varying,
    email character varying,
    telefono character varying,
    cellulare character varying,
    note text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    posizione integer
);


--
-- Name: prezzi_ministeriali; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prezzi_ministeriali (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    anno_scolastico character varying NOT NULL,
    classe character varying NOT NULL,
    disciplina character varying NOT NULL,
    prezzo_cents integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    nome character varying,
    cognome character varying,
    ragione_sociale character varying,
    indirizzo character varying,
    cap character varying,
    citta character varying,
    cellulare character varying,
    email character varying,
    iban character varying,
    nome_banca character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.profiles_id_seq OWNED BY public.profiles.id;


--
-- Name: propagande; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.propagande (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nome character varying NOT NULL,
    account_id uuid NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qrcodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qrcodes (
    id bigint NOT NULL,
    description text,
    url character varying,
    qrcodable_type character varying,
    qrcodable_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: qrcodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.qrcodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: qrcodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.qrcodes_id_seq OWNED BY public.qrcodes.id;


--
-- Name: registrazioni; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registrazioni (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    registrabile_type character varying NOT NULL,
    registrabile_id uuid NOT NULL,
    user_id bigint,
    registrato_il timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: righe; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.righe (
    id bigint NOT NULL,
    libro_id bigint NOT NULL,
    quantita integer DEFAULT 1,
    prezzo_copertina_cents integer DEFAULT 0,
    prezzo_cents integer DEFAULT 0,
    sconto numeric(5,2) DEFAULT 0.0,
    iva_cents integer DEFAULT 0,
    status integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: righe_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.righe_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: righe_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.righe_id_seq OWNED BY public.righe.id;


--
-- Name: saggi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saggi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    user_id bigint NOT NULL,
    libro_id bigint NOT NULL,
    scuola_id uuid NOT NULL,
    destinatario_type character varying,
    destinatario_id character varying,
    stato integer DEFAULT 0 NOT NULL,
    quantita integer DEFAULT 1 NOT NULL,
    data_prenotazione date,
    data_consegna date,
    note text,
    documento_riga_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: saldi; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saldi (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    saldabile_type character varying NOT NULL,
    saldabile_id uuid NOT NULL,
    copie_da_consegnare integer DEFAULT 0 NOT NULL,
    importo_da_consegnare_cents bigint DEFAULT 0 NOT NULL,
    copie_da_pagare integer DEFAULT 0 NOT NULL,
    importo_da_pagare_cents bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: scartate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scartate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scuola_id uuid NOT NULL,
    user_id bigint NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sconti; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sconti (
    id bigint NOT NULL,
    scontabile_type character varying,
    categoria_id bigint,
    percentuale_sconto numeric(5,2) NOT NULL,
    data_inizio date NOT NULL,
    data_fine date,
    tipo_sconto integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint,
    account_id uuid NOT NULL,
    scontabile_id uuid
);


--
-- Name: sconti_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sconti_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sconti_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sconti_id_seq OWNED BY public.sconti.id;


--
-- Name: scuole; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scuole (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    import_scuola_id bigint,
    codice_ministeriale character varying,
    denominazione character varying,
    indirizzo character varying,
    cap character varying,
    comune character varying,
    provincia character varying,
    regione character varying,
    tipo_scuola character varying,
    email character varying,
    pec character varying,
    telefono character varying,
    note text,
    priorita integer DEFAULT 0,
    stato character varying DEFAULT 'attiva'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    latitude double precision,
    longitude double precision,
    posizione integer DEFAULT 0,
    grado character varying,
    direzione_id uuid,
    sigla_provincia character varying(2),
    area character varying,
    classi_count integer DEFAULT 0 NOT NULL,
    adozioni_count integer DEFAULT 0 NOT NULL,
    mie_adozioni_count integer DEFAULT 0 NOT NULL,
    email_pattern character varying,
    email_dominio character varying
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id bigint NOT NULL,
    account_id uuid,
    token character varying NOT NULL,
    ip_address character varying,
    user_agent character varying,
    last_active_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stats (
    id bigint NOT NULL,
    descrizione character varying,
    seleziona_campi character varying,
    raggruppa_per character varying,
    ordina_per character varying,
    condizioni character varying,
    testo text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    titolo character varying,
    categoria character varying,
    anno character varying,
    visible boolean DEFAULT true NOT NULL,
    "position" integer,
    stato character varying DEFAULT 'lab'::character varying NOT NULL,
    ultima_verifica timestamp(6) without time zone,
    ultimo_errore text
);


--
-- Name: stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stats_id_seq OWNED BY public.stats.id;


--
-- Name: tappa_giri; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tappa_giri (
    id bigint NOT NULL,
    giro_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tappa_id uuid
);


--
-- Name: tappa_giri_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tappa_giri_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tappa_giri_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tappa_giri_id_seq OWNED BY public.tappa_giri.id;


--
-- Name: tappe; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tappe (
    titolo character varying,
    descrizione character varying,
    data_tappa date,
    entro_il timestamp(6) without time zone,
    tappable_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    giro_id bigint,
    user_id bigint,
    "position" integer NOT NULL,
    account_id uuid NOT NULL,
    tappable_id uuid,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: tipi_scuole; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tipi_scuole (
    id bigint NOT NULL,
    tipo character varying,
    grado character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tipi_scuole_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tipi_scuole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tipi_scuole_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tipi_scuole_id_seq OWNED BY public.tipi_scuole.id;


--
-- Name: tool_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tool_calls (
    id bigint NOT NULL,
    tool_call_id character varying NOT NULL,
    name character varying NOT NULL,
    arguments jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    message_id bigint NOT NULL
);


--
-- Name: tool_calls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tool_calls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tool_calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tool_calls_id_seq OWNED BY public.tool_calls.id;


--
-- Name: user_scuole; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_scuole (
    id bigint NOT NULL,
    import_scuola_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    "position" integer
);


--
-- Name: user_scuole_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_scuole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_scuole_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_scuole_id_seq OWNED BY public.user_scuole.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying,
    email character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    navigator character varying,
    role integer DEFAULT 0,
    slug character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: view_classi; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.view_classi AS
 SELECT DISTINCT row_number() OVER (PARTITION BY true::boolean) AS id,
    import_scuole."AREAGEOGRAFICA" AS area_geografica,
    import_scuole."REGIONE" AS regione,
    import_scuole."PROVINCIA" AS provincia,
    import_scuole."CODICESCUOLA" AS codice_ministeriale,
    miur_adozioni.annocorso AS classe,
    miur_adozioni.sezioneanno AS sezione,
    miur_adozioni.combinazione,
    array_agg(miur_adozioni.id) AS import_adozioni_ids,
    import_scuole."ANNOSCOLASTICO" AS anno
   FROM (public.import_scuole
     JOIN public.miur_adozioni ON (((miur_adozioni.codicescuola)::text = (import_scuole."CODICESCUOLA")::text)))
  WHERE ((miur_adozioni.anno_scolastico)::text = '202526'::text)
  GROUP BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", miur_adozioni.annocorso, miur_adozioni.sezioneanno, miur_adozioni.combinazione, import_scuole."ANNOSCOLASTICO"
  ORDER BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", miur_adozioni.annocorso, miur_adozioni.sezioneanno, miur_adozioni.combinazione
  WITH NO DATA;


--
-- Name: view_giacenze; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_giacenze AS
 SELECT users.id AS user_id,
    libri.id AS libro_id,
    libri.titolo,
    libri.codice_isbn,
    (COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 1) AND (documenti.status = 0))), (0)::bigint) - COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 0) AND (documenti.status = 0))), (0)::bigint)) AS ordini,
    (COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 1) AND (causali.tipo_movimento <> 2) AND (documenti.status <> 0))), (0)::bigint) - COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 0) AND (causali.tipo_movimento <> 2) AND (documenti.status <> 0))), (0)::bigint)) AS vendite,
    (COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 0) AND (causali.tipo_movimento = 2))), (0)::bigint) - COALESCE(sum(righe.quantita) FILTER (WHERE ((causali.movimento = 1) AND (causali.tipo_movimento = 2))), (0)::bigint)) AS carichi
   FROM (((((public.righe
     JOIN public.libri ON ((righe.libro_id = libri.id)))
     JOIN public.documento_righe ON ((righe.id = documento_righe.riga_id)))
     JOIN public.documenti ON ((documento_righe.documento_id = documenti.id)))
     JOIN public.causali ON ((documenti.causale_id = causali.id)))
     JOIN public.users ON ((users.id = documenti.user_id)))
  GROUP BY users.id, libri.id, libri.titolo, libri.codice_isbn
  ORDER BY libri.titolo;


--
-- Name: voice_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.voice_notes (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    title text,
    transcription text
);


--
-- Name: voice_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.voice_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: voice_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.voice_notes_id_seq OWNED BY public.voice_notes.id;


--
-- Name: zone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zone (
    id bigint NOT NULL,
    area_geografica character varying,
    regione character varying,
    provincia character varying,
    comune character varying,
    codice_comune character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sigla character varying(2)
);


--
-- Name: zone_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zone_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zone_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zone_id_seq OWNED BY public.zone.id;


--
-- Name: miur_adozioni_202425; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni ATTACH PARTITION public.miur_adozioni_202425 FOR VALUES IN ('202425');


--
-- Name: miur_adozioni_202526; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni ATTACH PARTITION public.miur_adozioni_202526 FOR VALUES IN ('202526');


--
-- Name: miur_adozioni_202627; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni ATTACH PARTITION public.miur_adozioni_202627 FOR VALUES IN ('202627');


--
-- Name: miur_scuole_202425; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole ATTACH PARTITION public.miur_scuole_202425 FOR VALUES IN ('202425');


--
-- Name: miur_scuole_202526; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole ATTACH PARTITION public.miur_scuole_202526 FOR VALUES IN ('202526');


--
-- Name: miur_scuole_202627; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole ATTACH PARTITION public.miur_scuole_202627 FOR VALUES IN ('202627');


--
-- Name: action_text_rich_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts ALTER COLUMN id SET DEFAULT nextval('public.action_text_rich_texts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: adozioni_comunicate id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni_comunicate ALTER COLUMN id SET DEFAULT nextval('public.adozioni_comunicate_id_seq'::regclass);


--
-- Name: ahoy_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ahoy_events ALTER COLUMN id SET DEFAULT nextval('public.ahoy_events_id_seq'::regclass);


--
-- Name: ahoy_visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ahoy_visits ALTER COLUMN id SET DEFAULT nextval('public.ahoy_visits_id_seq'::regclass);


--
-- Name: aziende id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aziende ALTER COLUMN id SET DEFAULT nextval('public.aziende_id_seq'::regclass);


--
-- Name: blazer_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_audits ALTER COLUMN id SET DEFAULT nextval('public.blazer_audits_id_seq'::regclass);


--
-- Name: blazer_checks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_checks ALTER COLUMN id SET DEFAULT nextval('public.blazer_checks_id_seq'::regclass);


--
-- Name: blazer_dashboard_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboard_queries ALTER COLUMN id SET DEFAULT nextval('public.blazer_dashboard_queries_id_seq'::regclass);


--
-- Name: blazer_dashboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboards ALTER COLUMN id SET DEFAULT nextval('public.blazer_dashboards_id_seq'::regclass);


--
-- Name: blazer_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_queries ALTER COLUMN id SET DEFAULT nextval('public.blazer_queries_id_seq'::regclass);


--
-- Name: categorie id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorie ALTER COLUMN id SET DEFAULT nextval('public.categorie_id_seq'::regclass);


--
-- Name: causali id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.causali ALTER COLUMN id SET DEFAULT nextval('public.causali_id_seq'::regclass);


--
-- Name: chats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats ALTER COLUMN id SET DEFAULT nextval('public.chats_id_seq'::regclass);


--
-- Name: confezione_righe id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confezione_righe ALTER COLUMN id SET DEFAULT nextval('public.confezione_righe_id_seq'::regclass);


--
-- Name: documento_righe id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documento_righe ALTER COLUMN id SET DEFAULT nextval('public.documento_righe_id_seq'::regclass);


--
-- Name: editori id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.editori ALTER COLUMN id SET DEFAULT nextval('public.editori_id_seq'::regclass);


--
-- Name: edizioni_titoli id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edizioni_titoli ALTER COLUMN id SET DEFAULT nextval('public.edizioni_titoli_id_seq'::regclass);


--
-- Name: friendly_id_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs ALTER COLUMN id SET DEFAULT nextval('public.friendly_id_slugs_id_seq'::regclass);


--
-- Name: giri id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giri ALTER COLUMN id SET DEFAULT nextval('public.giri_id_seq'::regclass);


--
-- Name: import_adozioni id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_adozioni ALTER COLUMN id SET DEFAULT nextval('public.miur_adozioni_id_seq'::regclass);


--
-- Name: import_scuole id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_scuole ALTER COLUMN id SET DEFAULT nextval('public.import_scuole_id_seq'::regclass);


--
-- Name: imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports ALTER COLUMN id SET DEFAULT nextval('public.imports_id_seq'::regclass);


--
-- Name: libri id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libri ALTER COLUMN id SET DEFAULT nextval('public.libri_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: miur_import_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_import_runs ALTER COLUMN id SET DEFAULT nextval('public.miur_import_runs_id_seq'::regclass);


--
-- Name: models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.models ALTER COLUMN id SET DEFAULT nextval('public.models_id_seq'::regclass);


--
-- Name: motor_alert_locks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_alert_locks ALTER COLUMN id SET DEFAULT nextval('public.motor_alert_locks_id_seq'::regclass);


--
-- Name: motor_alerts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_alerts ALTER COLUMN id SET DEFAULT nextval('public.motor_alerts_id_seq'::regclass);


--
-- Name: motor_api_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_api_configs ALTER COLUMN id SET DEFAULT nextval('public.motor_api_configs_id_seq'::regclass);


--
-- Name: motor_audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_audits ALTER COLUMN id SET DEFAULT nextval('public.motor_audits_id_seq'::regclass);


--
-- Name: motor_configs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_configs ALTER COLUMN id SET DEFAULT nextval('public.motor_configs_id_seq'::regclass);


--
-- Name: motor_dashboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_dashboards ALTER COLUMN id SET DEFAULT nextval('public.motor_dashboards_id_seq'::regclass);


--
-- Name: motor_forms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_forms ALTER COLUMN id SET DEFAULT nextval('public.motor_forms_id_seq'::regclass);


--
-- Name: motor_note_tag_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_note_tag_tags ALTER COLUMN id SET DEFAULT nextval('public.motor_note_tag_tags_id_seq'::regclass);


--
-- Name: motor_note_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_note_tags ALTER COLUMN id SET DEFAULT nextval('public.motor_note_tags_id_seq'::regclass);


--
-- Name: motor_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_notes ALTER COLUMN id SET DEFAULT nextval('public.motor_notes_id_seq'::regclass);


--
-- Name: motor_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_notifications ALTER COLUMN id SET DEFAULT nextval('public.motor_notifications_id_seq'::regclass);


--
-- Name: motor_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_queries ALTER COLUMN id SET DEFAULT nextval('public.motor_queries_id_seq'::regclass);


--
-- Name: motor_reminders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_reminders ALTER COLUMN id SET DEFAULT nextval('public.motor_reminders_id_seq'::regclass);


--
-- Name: motor_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_resources ALTER COLUMN id SET DEFAULT nextval('public.motor_resources_id_seq'::regclass);


--
-- Name: motor_taggable_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_taggable_tags ALTER COLUMN id SET DEFAULT nextval('public.motor_taggable_tags_id_seq'::regclass);


--
-- Name: motor_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_tags ALTER COLUMN id SET DEFAULT nextval('public.motor_tags_id_seq'::regclass);


--
-- Name: profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles ALTER COLUMN id SET DEFAULT nextval('public.profiles_id_seq'::regclass);


--
-- Name: qrcodes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrcodes ALTER COLUMN id SET DEFAULT nextval('public.qrcodes_id_seq'::regclass);


--
-- Name: righe id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.righe ALTER COLUMN id SET DEFAULT nextval('public.righe_id_seq'::regclass);


--
-- Name: sconti id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sconti ALTER COLUMN id SET DEFAULT nextval('public.sconti_id_seq'::regclass);


--
-- Name: stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stats ALTER COLUMN id SET DEFAULT nextval('public.stats_id_seq'::regclass);


--
-- Name: tappa_giri id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappa_giri ALTER COLUMN id SET DEFAULT nextval('public.tappa_giri_id_seq'::regclass);


--
-- Name: tipi_scuole id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipi_scuole ALTER COLUMN id SET DEFAULT nextval('public.tipi_scuole_id_seq'::regclass);


--
-- Name: tool_calls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_calls ALTER COLUMN id SET DEFAULT nextval('public.tool_calls_id_seq'::regclass);


--
-- Name: user_scuole id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_scuole ALTER COLUMN id SET DEFAULT nextval('public.user_scuole_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: voice_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voice_notes ALTER COLUMN id SET DEFAULT nextval('public.voice_notes_id_seq'::regclass);


--
-- Name: zone id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone ALTER COLUMN id SET DEFAULT nextval('public.zone_id_seq'::regclass);


--
-- Name: access_tokens access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_pkey PRIMARY KEY (id);


--
-- Name: account_zone account_zone_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_zone
    ADD CONSTRAINT account_zone_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: adozioni_comunicate adozioni_comunicate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni_comunicate
    ADD CONSTRAINT adozioni_comunicate_pkey PRIMARY KEY (id);


--
-- Name: adozioni adozioni_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni
    ADD CONSTRAINT adozioni_pkey PRIMARY KEY (id);


--
-- Name: ahoy_events ahoy_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ahoy_events
    ADD CONSTRAINT ahoy_events_pkey PRIMARY KEY (id);


--
-- Name: ahoy_visits ahoy_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ahoy_visits
    ADD CONSTRAINT ahoy_visits_pkey PRIMARY KEY (id);


--
-- Name: appunti appunti_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appunti
    ADD CONSTRAINT appunti_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: aziende aziende_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aziende
    ADD CONSTRAINT aziende_pkey PRIMARY KEY (id);


--
-- Name: blazer_audits blazer_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_audits
    ADD CONSTRAINT blazer_audits_pkey PRIMARY KEY (id);


--
-- Name: blazer_checks blazer_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_checks
    ADD CONSTRAINT blazer_checks_pkey PRIMARY KEY (id);


--
-- Name: blazer_dashboard_queries blazer_dashboard_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboard_queries
    ADD CONSTRAINT blazer_dashboard_queries_pkey PRIMARY KEY (id);


--
-- Name: blazer_dashboards blazer_dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_dashboards
    ADD CONSTRAINT blazer_dashboards_pkey PRIMARY KEY (id);


--
-- Name: blazer_queries blazer_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blazer_queries
    ADD CONSTRAINT blazer_queries_pkey PRIMARY KEY (id);


--
-- Name: bolla_visione_righe bolla_visione_righe_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bolla_visione_righe
    ADD CONSTRAINT bolla_visione_righe_pkey PRIMARY KEY (id);


--
-- Name: bolle_visione bolle_visione_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bolle_visione
    ADD CONSTRAINT bolle_visione_pkey PRIMARY KEY (id);


--
-- Name: categorie categorie_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorie
    ADD CONSTRAINT categorie_pkey PRIMARY KEY (id);


--
-- Name: cattedra_discipline cattedra_discipline_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cattedra_discipline
    ADD CONSTRAINT cattedra_discipline_pkey PRIMARY KEY (id);


--
-- Name: causali causali_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.causali
    ADD CONSTRAINT causali_pkey PRIMARY KEY (id);


--
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (id);


--
-- Name: classi classi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classi
    ADD CONSTRAINT classi_pkey PRIMARY KEY (id);


--
-- Name: clienti clienti_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clienti
    ADD CONSTRAINT clienti_pkey PRIMARY KEY (id);


--
-- Name: closures closures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.closures
    ADD CONSTRAINT closures_pkey PRIMARY KEY (id);


--
-- Name: collana_libri collana_libri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collana_libri
    ADD CONSTRAINT collana_libri_pkey PRIMARY KEY (id);


--
-- Name: collane collane_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.collane
    ADD CONSTRAINT collane_pkey PRIMARY KEY (id);


--
-- Name: columns columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.columns
    ADD CONSTRAINT columns_pkey PRIMARY KEY (id);


--
-- Name: confezione_righe confezione_righe_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.confezione_righe
    ADD CONSTRAINT confezione_righe_pkey PRIMARY KEY (id);


--
-- Name: consegne consegne_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consegne
    ADD CONSTRAINT consegne_pkey PRIMARY KEY (id);


--
-- Name: consegne_saggio consegne_saggio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consegne_saggio
    ADD CONSTRAINT consegne_saggio_pkey PRIMARY KEY (id);


--
-- Name: controllo_anomalie controllo_anomalie_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controllo_anomalie
    ADD CONSTRAINT controllo_anomalie_pkey PRIMARY KEY (id);


--
-- Name: disponibilita disponibilita_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disponibilita
    ADD CONSTRAINT disponibilita_pkey PRIMARY KEY (id);


--
-- Name: documenti documenti_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documenti
    ADD CONSTRAINT documenti_pkey PRIMARY KEY (id);


--
-- Name: documento_righe documento_righe_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documento_righe
    ADD CONSTRAINT documento_righe_pkey PRIMARY KEY (id);


--
-- Name: editori editori_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.editori
    ADD CONSTRAINT editori_pkey PRIMARY KEY (id);


--
-- Name: edizioni_titoli edizioni_titoli_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edizioni_titoli
    ADD CONSTRAINT edizioni_titoli_pkey PRIMARY KEY (id);


--
-- Name: entries entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: filters filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters
    ADD CONSTRAINT filters_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: giri giri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giri
    ADD CONSTRAINT giri_pkey PRIMARY KEY (id);


--
-- Name: goldnesses goldnesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goldnesses
    ADD CONSTRAINT goldnesses_pkey PRIMARY KEY (id);


--
-- Name: import_records import_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_records
    ADD CONSTRAINT import_records_pkey PRIMARY KEY (id);


--
-- Name: import_scuole import_scuole_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_scuole
    ADD CONSTRAINT import_scuole_pkey PRIMARY KEY (id);


--
-- Name: imports imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.imports
    ADD CONSTRAINT imports_pkey PRIMARY KEY (id);


--
-- Name: libri libri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libri
    ADD CONSTRAINT libri_pkey PRIMARY KEY (id);


--
-- Name: magic_links magic_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.magic_links
    ADD CONSTRAINT magic_links_pkey PRIMARY KEY (id);


--
-- Name: legacy_mandati mandati_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_mandati
    ADD CONSTRAINT mandati_pkey PRIMARY KEY (user_id, editore_id);


--
-- Name: mandati mandati_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandati
    ADD CONSTRAINT mandati_pkey1 PRIMARY KEY (id);


--
-- Name: membership_scuole membership_scuole_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_scuole
    ADD CONSTRAINT membership_scuole_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: miur_adozioni miur_adozioni_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni
    ADD CONSTRAINT miur_adozioni_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_adozioni_202425 miur_adozioni_202425_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni_202425
    ADD CONSTRAINT miur_adozioni_202425_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_adozioni_202526 miur_adozioni_202526_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni_202526
    ADD CONSTRAINT miur_adozioni_202526_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_adozioni_202627 miur_adozioni_202627_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_adozioni_202627
    ADD CONSTRAINT miur_adozioni_202627_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_import_runs miur_import_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_import_runs
    ADD CONSTRAINT miur_import_runs_pkey PRIMARY KEY (id);


--
-- Name: miur_scuole miur_scuole_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole
    ADD CONSTRAINT miur_scuole_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_scuole_202425 miur_scuole_202425_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole_202425
    ADD CONSTRAINT miur_scuole_202425_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_scuole_202526 miur_scuole_202526_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole_202526
    ADD CONSTRAINT miur_scuole_202526_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: miur_scuole_202627 miur_scuole_202627_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.miur_scuole_202627
    ADD CONSTRAINT miur_scuole_202627_pkey PRIMARY KEY (anno_scolastico, id);


--
-- Name: models models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.models
    ADD CONSTRAINT models_pkey PRIMARY KEY (id);


--
-- Name: motor_alert_locks motor_alert_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_alert_locks
    ADD CONSTRAINT motor_alert_locks_pkey PRIMARY KEY (id);


--
-- Name: motor_alerts motor_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_alerts
    ADD CONSTRAINT motor_alerts_pkey PRIMARY KEY (id);


--
-- Name: motor_api_configs motor_api_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_api_configs
    ADD CONSTRAINT motor_api_configs_pkey PRIMARY KEY (id);


--
-- Name: motor_audits motor_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_audits
    ADD CONSTRAINT motor_audits_pkey PRIMARY KEY (id);


--
-- Name: motor_configs motor_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_configs
    ADD CONSTRAINT motor_configs_pkey PRIMARY KEY (id);


--
-- Name: motor_dashboards motor_dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_dashboards
    ADD CONSTRAINT motor_dashboards_pkey PRIMARY KEY (id);


--
-- Name: motor_forms motor_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_forms
    ADD CONSTRAINT motor_forms_pkey PRIMARY KEY (id);


--
-- Name: motor_note_tag_tags motor_note_tag_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_note_tag_tags
    ADD CONSTRAINT motor_note_tag_tags_pkey PRIMARY KEY (id);


--
-- Name: motor_note_tags motor_note_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_note_tags
    ADD CONSTRAINT motor_note_tags_pkey PRIMARY KEY (id);


--
-- Name: motor_notes motor_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_notes
    ADD CONSTRAINT motor_notes_pkey PRIMARY KEY (id);


--
-- Name: motor_notifications motor_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_notifications
    ADD CONSTRAINT motor_notifications_pkey PRIMARY KEY (id);


--
-- Name: motor_queries motor_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_queries
    ADD CONSTRAINT motor_queries_pkey PRIMARY KEY (id);


--
-- Name: motor_reminders motor_reminders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_reminders
    ADD CONSTRAINT motor_reminders_pkey PRIMARY KEY (id);


--
-- Name: motor_resources motor_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_resources
    ADD CONSTRAINT motor_resources_pkey PRIMARY KEY (id);


--
-- Name: motor_taggable_tags motor_taggable_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_taggable_tags
    ADD CONSTRAINT motor_taggable_tags_pkey PRIMARY KEY (id);


--
-- Name: motor_tags motor_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_tags
    ADD CONSTRAINT motor_tags_pkey PRIMARY KEY (id);


--
-- Name: not_nows not_nows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.not_nows
    ADD CONSTRAINT not_nows_pkey PRIMARY KEY (id);


--
-- Name: pagamenti pagamenti_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamenti
    ADD CONSTRAINT pagamenti_pkey PRIMARY KEY (id);


--
-- Name: persona_classi persona_classi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persona_classi
    ADD CONSTRAINT persona_classi_pkey PRIMARY KEY (id);


--
-- Name: personal_infos personal_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_infos
    ADD CONSTRAINT personal_infos_pkey PRIMARY KEY (id);


--
-- Name: persone persone_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT persone_pkey PRIMARY KEY (id);


--
-- Name: prezzi_ministeriali prezzi_ministeriali_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prezzi_ministeriali
    ADD CONSTRAINT prezzi_ministeriali_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: propagande propagande_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.propagande
    ADD CONSTRAINT propagande_pkey PRIMARY KEY (id);


--
-- Name: qrcodes qrcodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qrcodes
    ADD CONSTRAINT qrcodes_pkey PRIMARY KEY (id);


--
-- Name: registrazioni registrazioni_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registrazioni
    ADD CONSTRAINT registrazioni_pkey PRIMARY KEY (id);


--
-- Name: righe righe_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.righe
    ADD CONSTRAINT righe_pkey PRIMARY KEY (id);


--
-- Name: saggi saggi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saggi
    ADD CONSTRAINT saggi_pkey PRIMARY KEY (id);


--
-- Name: saldi saldi_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saldi
    ADD CONSTRAINT saldi_pkey PRIMARY KEY (id);


--
-- Name: scartate scartate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scartate
    ADD CONSTRAINT scartate_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sconti sconti_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sconti
    ADD CONSTRAINT sconti_pkey PRIMARY KEY (id);


--
-- Name: scuole scuole_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scuole
    ADD CONSTRAINT scuole_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: stats stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stats
    ADD CONSTRAINT stats_pkey PRIMARY KEY (id);


--
-- Name: tappa_giri tappa_giri_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappa_giri
    ADD CONSTRAINT tappa_giri_pkey PRIMARY KEY (id);


--
-- Name: tappe tappe_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappe
    ADD CONSTRAINT tappe_pkey PRIMARY KEY (id);


--
-- Name: tipi_scuole tipi_scuole_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tipi_scuole
    ADD CONSTRAINT tipi_scuole_pkey PRIMARY KEY (id);


--
-- Name: tool_calls tool_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_calls
    ADD CONSTRAINT tool_calls_pkey PRIMARY KEY (id);


--
-- Name: user_scuole user_scuole_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_scuole
    ADD CONSTRAINT user_scuole_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: voice_notes voice_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voice_notes
    ADD CONSTRAINT voice_notes_pkey PRIMARY KEY (id);


--
-- Name: zone zone_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone
    ADD CONSTRAINT zone_pkey PRIMARY KEY (id);


--
-- Name: idx_account_zone_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_account_zone_unique ON public.account_zone USING btree (account_id, provincia, grado, anno_scolastico);


--
-- Name: idx_cattedra_discipline_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_cattedra_discipline_unique ON public.cattedra_discipline USING btree (account_id, cattedra, disciplina, tipo_scuola);


--
-- Name: idx_disponibilita_scuola_tipo_giorno; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_disponibilita_scuola_tipo_giorno ON public.disponibilita USING btree (scuola_id, tipo, giorno_settimana);


--
-- Name: idx_mandati_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mandati_unique ON public.mandati USING btree (account_id, editore_id, provincia, grado, anno_scolastico, area) NULLS NOT DISTINCT;


--
-- Name: idx_mercato_naz_libri_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mercato_naz_libri_pk ON public.mercato_nazionale_libri USING btree (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso, codice_isbn);


--
-- Name: idx_mercato_naz_mercati_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mercato_naz_mercati_pk ON public.mercato_nazionale_mercati USING btree (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso);


--
-- Name: idx_mercato_scuola_mercati_pk; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_mercato_scuola_mercati_pk ON public.mercato_scuola_mercati USING btree (anno_scolastico, codice_scuola, tipo_grado_scuola, disciplina, anno_corso);


--
-- Name: idx_mercato_scuola_mercati_scuola; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mercato_scuola_mercati_scuola ON public.mercato_scuola_mercati USING btree (codice_scuola);


--
-- Name: idx_miur_adoz_ee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_miur_adoz_ee ON ONLY public.miur_adozioni USING btree (codicescuola) INCLUDE (editore, annocorso, disciplina) WHERE ((tipogradoscuola)::text = 'EE'::text);


--
-- Name: idx_miur_adozioni_codicescuola; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_miur_adozioni_codicescuola ON ONLY public.miur_adozioni USING btree (codicescuola);


--
-- Name: idx_miur_adozioni_disc_anno_tg; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_miur_adozioni_disc_anno_tg ON ONLY public.miur_adozioni USING btree (disciplina, annocorso, tipogradoscuola);


--
-- Name: idx_miur_scuole_cod; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_miur_scuole_cod ON ONLY public.miur_scuole USING btree (codice_scuola) INCLUDE (regione, provincia);


--
-- Name: idx_miur_scuole_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_miur_scuole_tipo ON ONLY public.miur_scuole USING btree (tipo_scuola);


--
-- Name: idx_on_DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA_20c3bcb01a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "idx_on_DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA_20c3bcb01a" ON public.import_scuole USING btree ("DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA");


--
-- Name: idx_on_codice_ministeriale_classe_sezione_combinazi_79414f61ec; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_codice_ministeriale_classe_sezione_combinazi_79414f61ec ON public.view_classi USING btree (codice_ministeriale, classe, sezione, combinazione);


--
-- Name: idx_prezzi_min_anno_classe_disc; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_prezzi_min_anno_classe_disc ON public.prezzi_ministeriali USING btree (anno_scolastico, classe, disciplina);


--
-- Name: idx_saggi_destinatario; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_saggi_destinatario ON public.saggi USING btree (destinatario_type, destinatario_id);


--
-- Name: index_access_tokens_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_access_tokens_on_membership_id ON public.access_tokens USING btree (membership_id);


--
-- Name: index_access_tokens_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_access_tokens_on_token ON public.access_tokens USING btree (token);


--
-- Name: index_account_zone_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_zone_on_account_id ON public.account_zone USING btree (account_id);


--
-- Name: index_accounts_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_slug ON public.accounts USING btree (slug);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_adozioni_comunicate_on_cod_ministeriale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_comunicate_on_cod_ministeriale ON public.adozioni_comunicate USING btree (cod_ministeriale);


--
-- Name: index_adozioni_comunicate_on_ean; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_comunicate_on_ean ON public.adozioni_comunicate USING btree (ean);


--
-- Name: index_adozioni_comunicate_on_import_adozione_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_comunicate_on_import_adozione_id ON public.adozioni_comunicate USING btree (import_adozione_id);


--
-- Name: index_adozioni_comunicate_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_comunicate_on_user_id ON public.adozioni_comunicate USING btree (user_id);


--
-- Name: index_adozioni_comunicate_on_user_id_and_cod_ministeriale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_comunicate_on_user_id_and_cod_ministeriale ON public.adozioni_comunicate USING btree (user_id, cod_ministeriale);


--
-- Name: index_adozioni_comunicate_on_user_id_and_ean; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_comunicate_on_user_id_and_ean ON public.adozioni_comunicate USING btree (user_id, ean);


--
-- Name: index_adozioni_on_account_classe_da_acquistare; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_account_classe_da_acquistare ON public.adozioni USING btree (account_id, classe_id) WHERE (da_acquistare = true);


--
-- Name: index_adozioni_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_account_id ON public.adozioni USING btree (account_id);


--
-- Name: index_adozioni_on_account_id_and_anno_scolastico; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_account_id_and_anno_scolastico ON public.adozioni USING btree (account_id, anno_scolastico);


--
-- Name: index_adozioni_on_account_id_and_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_account_id_and_libro_id ON public.adozioni USING btree (account_id, libro_id);


--
-- Name: index_adozioni_on_account_id_and_mia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_account_id_and_mia ON public.adozioni USING btree (account_id, mia);


--
-- Name: index_adozioni_on_classe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_classe_id ON public.adozioni USING btree (classe_id);


--
-- Name: index_adozioni_on_classe_isbn_anno; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_adozioni_on_classe_isbn_anno ON public.adozioni USING btree (classe_id, codice_isbn, anno_scolastico);


--
-- Name: index_adozioni_on_import_adozione_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_import_adozione_id ON public.adozioni USING btree (import_adozione_id);


--
-- Name: index_adozioni_on_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adozioni_on_libro_id ON public.adozioni USING btree (libro_id);


--
-- Name: index_ahoy_events_on_name_and_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ahoy_events_on_name_and_time ON public.ahoy_events USING btree (name, "time");


--
-- Name: index_ahoy_events_on_properties; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ahoy_events_on_properties ON public.ahoy_events USING gin (properties jsonb_path_ops);


--
-- Name: index_ahoy_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ahoy_events_on_user_id ON public.ahoy_events USING btree (user_id);


--
-- Name: index_ahoy_events_on_visit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ahoy_events_on_visit_id ON public.ahoy_events USING btree (visit_id);


--
-- Name: index_ahoy_visits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ahoy_visits_on_user_id ON public.ahoy_visits USING btree (user_id);


--
-- Name: index_ahoy_visits_on_visit_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ahoy_visits_on_visit_token ON public.ahoy_visits USING btree (visit_token);


--
-- Name: index_ahoy_visits_on_visitor_token_and_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ahoy_visits_on_visitor_token_and_started_at ON public.ahoy_visits USING btree (visitor_token, started_at);


--
-- Name: index_appunti_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_account_id ON public.appunti USING btree (account_id);


--
-- Name: index_appunti_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_account_id_and_created_at ON public.appunti USING btree (account_id, created_at);


--
-- Name: index_appunti_on_account_id_and_numero_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_account_id_and_numero_and_created_at ON public.appunti USING btree (account_id, numero, created_at);


--
-- Name: index_appunti_on_account_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_account_id_and_status ON public.appunti USING btree (account_id, status);


--
-- Name: index_appunti_on_appuntabile_type_and_appuntabile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_appuntabile_type_and_appuntabile_id ON public.appunti USING btree (appuntabile_type, appuntabile_id);


--
-- Name: index_appunti_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_appunti_on_id ON public.appunti USING btree (id);


--
-- Name: index_appunti_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_user_id ON public.appunti USING btree (user_id);


--
-- Name: index_appunti_on_voice_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appunti_on_voice_note_id ON public.appunti USING btree (voice_note_id);


--
-- Name: index_aziende_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_aziende_on_account_id ON public.aziende USING btree (account_id);


--
-- Name: index_aziende_on_account_id_and_codice_fiscale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_aziende_on_account_id_and_codice_fiscale ON public.aziende USING btree (account_id, codice_fiscale);


--
-- Name: index_aziende_on_account_id_and_partita_iva; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_aziende_on_account_id_and_partita_iva ON public.aziende USING btree (account_id, partita_iva);


--
-- Name: index_aziende_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aziende_on_user_id ON public.aziende USING btree (user_id);


--
-- Name: index_blazer_audits_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_audits_on_query_id ON public.blazer_audits USING btree (query_id);


--
-- Name: index_blazer_audits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_audits_on_user_id ON public.blazer_audits USING btree (user_id);


--
-- Name: index_blazer_checks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_checks_on_creator_id ON public.blazer_checks USING btree (creator_id);


--
-- Name: index_blazer_checks_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_checks_on_query_id ON public.blazer_checks USING btree (query_id);


--
-- Name: index_blazer_dashboard_queries_on_dashboard_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_dashboard_queries_on_dashboard_id ON public.blazer_dashboard_queries USING btree (dashboard_id);


--
-- Name: index_blazer_dashboard_queries_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_dashboard_queries_on_query_id ON public.blazer_dashboard_queries USING btree (query_id);


--
-- Name: index_blazer_dashboards_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_dashboards_on_creator_id ON public.blazer_dashboards USING btree (creator_id);


--
-- Name: index_blazer_queries_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blazer_queries_on_creator_id ON public.blazer_queries USING btree (creator_id);


--
-- Name: index_bolla_visione_righe_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolla_visione_righe_on_account_id ON public.bolla_visione_righe USING btree (account_id);


--
-- Name: index_bolla_visione_righe_on_bolla_visione_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolla_visione_righe_on_bolla_visione_id ON public.bolla_visione_righe USING btree (bolla_visione_id);


--
-- Name: index_bolla_visione_righe_on_bolla_visione_id_and_esito; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolla_visione_righe_on_bolla_visione_id_and_esito ON public.bolla_visione_righe USING btree (bolla_visione_id, esito);


--
-- Name: index_bolla_visione_righe_on_documento_riga_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolla_visione_righe_on_documento_riga_id ON public.bolla_visione_righe USING btree (documento_riga_id);


--
-- Name: index_bolla_visione_righe_on_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolla_visione_righe_on_libro_id ON public.bolla_visione_righe USING btree (libro_id);


--
-- Name: index_bolla_visione_righe_on_processato_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolla_visione_righe_on_processato_at ON public.bolla_visione_righe USING btree (processato_at);


--
-- Name: index_bolle_visione_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolle_visione_on_account_id ON public.bolle_visione USING btree (account_id);


--
-- Name: index_bolle_visione_on_account_id_and_numero; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_bolle_visione_on_account_id_and_numero ON public.bolle_visione USING btree (account_id, numero);


--
-- Name: index_bolle_visione_on_collana_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolle_visione_on_collana_id ON public.bolle_visione USING btree (collana_id);


--
-- Name: index_bolle_visione_on_contatto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolle_visione_on_contatto_id ON public.bolle_visione USING btree (contatto_id);


--
-- Name: index_bolle_visione_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolle_visione_on_scuola_id ON public.bolle_visione USING btree (scuola_id);


--
-- Name: index_bolle_visione_on_tappa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolle_visione_on_tappa_id ON public.bolle_visione USING btree (tappa_id);


--
-- Name: index_bolle_visione_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bolle_visione_on_user_id ON public.bolle_visione USING btree (user_id);


--
-- Name: index_categorie_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categorie_on_account_id ON public.categorie USING btree (account_id);


--
-- Name: index_categorie_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categorie_on_user_id ON public.categorie USING btree (user_id);


--
-- Name: index_categorie_on_user_id_and_nome_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categorie_on_user_id_and_nome_categoria ON public.categorie USING btree (user_id, lower(TRIM(BOTH FROM nome_categoria)));


--
-- Name: index_cattedra_discipline_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cattedra_discipline_on_account_id ON public.cattedra_discipline USING btree (account_id);


--
-- Name: index_causali_on_priorita; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_causali_on_priorita ON public.causali USING btree (priorita);


--
-- Name: index_causali_on_stato_iniziale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_causali_on_stato_iniziale ON public.causali USING btree (stato_iniziale);


--
-- Name: index_chats_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chats_on_account_id ON public.chats USING btree (account_id);


--
-- Name: index_chats_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chats_on_model_id ON public.chats USING btree (model_id);


--
-- Name: index_chats_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chats_on_user_id ON public.chats USING btree (user_id);


--
-- Name: index_classi_attive_on_scuola_anno_sezione_combinazione; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_classi_attive_on_scuola_anno_sezione_combinazione ON public.classi USING btree (scuola_id, anno_corso, sezione, combinazione) WHERE ((stato)::text = 'attiva'::text);


--
-- Name: index_classi_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classi_on_account_id ON public.classi USING btree (account_id);


--
-- Name: index_classi_on_account_id_and_anno_scolastico; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classi_on_account_id_and_anno_scolastico ON public.classi USING btree (account_id, anno_scolastico);


--
-- Name: index_classi_on_origine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classi_on_origine ON public.classi USING btree (account_id, codice_ministeriale_origine, classe_origine, sezione_origine);


--
-- Name: index_classi_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_classi_on_scuola_id ON public.classi USING btree (scuola_id);


--
-- Name: index_clienti_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clienti_on_account_id ON public.clienti USING btree (account_id);


--
-- Name: index_clienti_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clienti_on_account_id_and_created_at ON public.clienti USING btree (account_id, created_at);


--
-- Name: index_clienti_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clienti_on_slug ON public.clienti USING btree (slug);


--
-- Name: index_clienti_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clienti_on_user_id ON public.clienti USING btree (user_id);


--
-- Name: index_closures_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closures_on_account_id ON public.closures USING btree (account_id);


--
-- Name: index_closures_on_closeable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closures_on_closeable ON public.closures USING btree (closeable_type, closeable_id);


--
-- Name: index_closures_on_closeable_type_and_closeable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_closures_on_closeable_type_and_closeable_id ON public.closures USING btree (closeable_type, closeable_id);


--
-- Name: index_closures_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_closures_on_entry_id ON public.closures USING btree (entry_id);


--
-- Name: index_closures_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_closures_on_user_id ON public.closures USING btree (user_id);


--
-- Name: index_collana_libri_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collana_libri_on_account_id ON public.collana_libri USING btree (account_id);


--
-- Name: index_collana_libri_on_collana_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collana_libri_on_collana_id ON public.collana_libri USING btree (collana_id);


--
-- Name: index_collana_libri_on_collana_id_and_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_collana_libri_on_collana_id_and_libro_id ON public.collana_libri USING btree (collana_id, libro_id);


--
-- Name: index_collana_libri_on_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collana_libri_on_libro_id ON public.collana_libri USING btree (libro_id);


--
-- Name: index_collane_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collane_on_account_id ON public.collane USING btree (account_id);


--
-- Name: index_collane_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_collane_on_user_id ON public.collane USING btree (user_id);


--
-- Name: index_columns_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_columns_on_account_id ON public.columns USING btree (account_id);


--
-- Name: index_columns_on_account_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_columns_on_account_id_and_name ON public.columns USING btree (account_id, name);


--
-- Name: index_columns_on_account_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_columns_on_account_id_and_position ON public.columns USING btree (account_id, "position");


--
-- Name: index_consegne_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_on_account_id ON public.consegne USING btree (account_id);


--
-- Name: index_consegne_on_consegnabile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_on_consegnabile ON public.consegne USING btree (consegnabile_type, consegnabile_id);


--
-- Name: index_consegne_on_consegnabile_type_and_consegnabile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consegne_on_consegnabile_type_and_consegnabile_id ON public.consegne USING btree (consegnabile_type, consegnabile_id);


--
-- Name: index_consegne_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_on_user_id ON public.consegne USING btree (user_id);


--
-- Name: index_consegne_saggio_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_saggio_on_account_id ON public.consegne_saggio USING btree (account_id);


--
-- Name: index_consegne_saggio_on_account_id_and_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_saggio_on_account_id_and_tipo ON public.consegne_saggio USING btree (account_id, tipo);


--
-- Name: index_consegne_saggio_on_adozione_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_saggio_on_adozione_id ON public.consegne_saggio USING btree (adozione_id);


--
-- Name: index_consegne_saggio_on_adozione_id_and_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_saggio_on_adozione_id_and_tipo ON public.consegne_saggio USING btree (adozione_id, tipo);


--
-- Name: index_consegne_saggio_on_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_saggio_on_libro_id ON public.consegne_saggio USING btree (libro_id);


--
-- Name: index_consegne_saggio_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consegne_saggio_on_user_id ON public.consegne_saggio USING btree (user_id);


--
-- Name: index_controllo_anomalie_on_anno_scolastico_and_codicescuola; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_controllo_anomalie_on_anno_scolastico_and_codicescuola ON public.controllo_anomalie USING btree (anno_scolastico, codicescuola);


--
-- Name: index_controllo_anomalie_on_codicescuola; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_controllo_anomalie_on_codicescuola ON public.controllo_anomalie USING btree (codicescuola);


--
-- Name: index_controllo_anomalie_on_provincia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_controllo_anomalie_on_provincia ON public.controllo_anomalie USING btree (provincia);


--
-- Name: index_controllo_anomalie_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_controllo_anomalie_on_tipo ON public.controllo_anomalie USING btree (tipo);


--
-- Name: index_disponibilita_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disponibilita_on_account_id ON public.disponibilita USING btree (account_id);


--
-- Name: index_disponibilita_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disponibilita_on_scuola_id ON public.disponibilita USING btree (scuola_id);


--
-- Name: index_disponibilita_on_scuola_id_and_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disponibilita_on_scuola_id_and_tipo ON public.disponibilita USING btree (scuola_id, tipo);


--
-- Name: index_disponibilita_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disponibilita_on_user_id ON public.disponibilita USING btree (user_id);


--
-- Name: index_documenti_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_account_id ON public.documenti USING btree (account_id);


--
-- Name: index_documenti_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_account_id_and_created_at ON public.documenti USING btree (account_id, created_at);


--
-- Name: index_documenti_on_causale_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_causale_id ON public.documenti USING btree (causale_id);


--
-- Name: index_documenti_on_clientable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_clientable ON public.documenti USING btree (clientable_type, clientable_id);


--
-- Name: index_documenti_on_derivato_da_causale_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_derivato_da_causale_id ON public.documenti USING btree (derivato_da_causale_id);


--
-- Name: index_documenti_on_documento_padre_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_documento_padre_id ON public.documenti USING btree (documento_padre_id);


--
-- Name: index_documenti_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documenti_on_user_id ON public.documenti USING btree (user_id);


--
-- Name: index_documento_righe_on_documento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documento_righe_on_documento_id ON public.documento_righe USING btree (documento_id);


--
-- Name: index_documento_righe_on_documento_id_and_riga_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_documento_righe_on_documento_id_and_riga_id ON public.documento_righe USING btree (documento_id, riga_id);


--
-- Name: index_documento_righe_on_riga_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documento_righe_on_riga_id ON public.documento_righe USING btree (riga_id);


--
-- Name: index_edizioni_titoli_on_codice_isbn; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_edizioni_titoli_on_codice_isbn ON public.edizioni_titoli USING btree (codice_isbn);


--
-- Name: index_entries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_account_id ON public.entries USING btree (account_id);


--
-- Name: index_entries_on_account_id_and_entryable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_account_id_and_entryable_type ON public.entries USING btree (account_id, entryable_type);


--
-- Name: index_entries_on_column_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_column_id ON public.entries USING btree (column_id);


--
-- Name: index_entries_on_entryable_type_and_entryable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entries_on_entryable_type_and_entryable_id ON public.entries USING btree (entryable_type, entryable_id);


--
-- Name: index_entries_on_giro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_giro_id ON public.entries USING btree (giro_id);


--
-- Name: index_entries_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entries_on_user_id ON public.entries USING btree (user_id);


--
-- Name: index_events_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_account_id ON public.events USING btree (account_id);


--
-- Name: index_events_on_account_id_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_account_id_and_action ON public.events USING btree (account_id, action);


--
-- Name: index_events_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_entry_id ON public.events USING btree (entry_id);


--
-- Name: index_events_on_entry_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_entry_id_and_created_at ON public.events USING btree (entry_id, created_at);


--
-- Name: index_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_user_id ON public.events USING btree (user_id);


--
-- Name: index_filters_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_on_account_id ON public.filters USING btree (account_id);


--
-- Name: index_filters_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_on_creator_id ON public.filters USING btree (creator_id);


--
-- Name: index_filters_on_type_and_params_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_filters_on_type_and_params_digest ON public.filters USING btree (type, params_digest);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type ON public.friendly_id_slugs USING btree (slug, sluggable_type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope ON public.friendly_id_slugs USING btree (slug, sluggable_type, scope);


--
-- Name: index_friendly_id_slugs_on_sluggable_type_and_sluggable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type_and_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_type, sluggable_id);


--
-- Name: index_giri_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_giri_on_account_id ON public.giri USING btree (account_id);


--
-- Name: index_giri_on_collana_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_giri_on_collana_id ON public.giri USING btree (collana_id);


--
-- Name: index_giri_on_propaganda_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_giri_on_propaganda_id ON public.giri USING btree (propaganda_id);


--
-- Name: index_giri_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_giri_on_user_id ON public.giri USING btree (user_id);


--
-- Name: index_goldnesses_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_goldnesses_on_account_id ON public.goldnesses USING btree (account_id);


--
-- Name: index_goldnesses_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_goldnesses_on_entry_id ON public.goldnesses USING btree (entry_id);


--
-- Name: index_goldnesses_on_goldenable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_goldnesses_on_goldenable ON public.goldnesses USING btree (goldenable_type, goldenable_id);


--
-- Name: index_goldnesses_on_goldenable_type_and_goldenable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_goldnesses_on_goldenable_type_and_goldenable_id ON public.goldnesses USING btree (goldenable_type, goldenable_id);


--
-- Name: index_goldnesses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_goldnesses_on_user_id ON public.goldnesses USING btree (user_id);


--
-- Name: index_import_records_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_records_on_account_id ON public.import_records USING btree (account_id);


--
-- Name: index_import_records_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_records_on_account_id_and_created_at ON public.import_records USING btree (account_id, created_at);


--
-- Name: index_import_records_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_records_on_user_id ON public.import_records USING btree (user_id);


--
-- Name: index_import_records_on_user_id_and_import_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_records_on_user_id_and_import_type ON public.import_records USING btree (user_id, import_type);


--
-- Name: index_import_scuole_on_CODICESCUOLA; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "index_import_scuole_on_CODICESCUOLA" ON public.import_scuole USING btree ("CODICESCUOLA");


--
-- Name: index_import_scuole_on_PROVINCIA; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX "index_import_scuole_on_PROVINCIA" ON public.import_scuole USING btree ("PROVINCIA");


--
-- Name: index_import_scuole_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_import_scuole_on_slug ON public.import_scuole USING btree (slug);


--
-- Name: index_legacy_mandati_on_editore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_mandati_on_editore_id ON public.legacy_mandati USING btree (editore_id);


--
-- Name: index_legacy_mandati_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_legacy_mandati_on_user_id ON public.legacy_mandati USING btree (user_id);


--
-- Name: index_libri_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_account_id ON public.libri USING btree (account_id);


--
-- Name: index_libri_on_account_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_account_id_and_created_at ON public.libri USING btree (account_id, created_at);


--
-- Name: index_libri_on_categoria_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_categoria_id ON public.libri USING btree (categoria_id);


--
-- Name: index_libri_on_classe_and_disciplina; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_classe_and_disciplina ON public.libri USING btree (classe, disciplina);


--
-- Name: index_libri_on_cm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_cm ON public.libri USING btree (cm);


--
-- Name: index_libri_on_editore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_editore_id ON public.libri USING btree (editore_id);


--
-- Name: index_libri_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_libri_on_slug ON public.libri USING btree (slug);


--
-- Name: index_libri_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_user_id ON public.libri USING btree (user_id);


--
-- Name: index_libri_on_user_id_and_codice_isbn; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_user_id_and_codice_isbn ON public.libri USING btree (user_id, codice_isbn);


--
-- Name: index_libri_on_user_id_and_collana; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_user_id_and_collana ON public.libri USING btree (user_id, collana);


--
-- Name: index_libri_on_user_id_and_editore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_user_id_and_editore_id ON public.libri USING btree (user_id, editore_id);


--
-- Name: index_libri_on_user_id_and_titolo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_libri_on_user_id_and_titolo ON public.libri USING btree (user_id, titolo);


--
-- Name: index_magic_links_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_magic_links_on_code ON public.magic_links USING btree (code);


--
-- Name: index_magic_links_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_expires_at ON public.magic_links USING btree (expires_at);


--
-- Name: index_magic_links_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_user_id ON public.magic_links USING btree (user_id);


--
-- Name: index_magic_links_on_user_id_and_purpose; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_magic_links_on_user_id_and_purpose ON public.magic_links USING btree (user_id, purpose);


--
-- Name: index_mandati_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mandati_on_account_id ON public.mandati USING btree (account_id);


--
-- Name: index_mandati_on_editore_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mandati_on_editore_id ON public.mandati USING btree (editore_id);


--
-- Name: index_membership_scuole_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_membership_scuole_on_membership_id ON public.membership_scuole USING btree (membership_id);


--
-- Name: index_membership_scuole_on_membership_id_and_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_membership_scuole_on_membership_id_and_scuola_id ON public.membership_scuole USING btree (membership_id, scuola_id);


--
-- Name: index_membership_scuole_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_membership_scuole_on_scuola_id ON public.membership_scuole USING btree (scuola_id);


--
-- Name: index_memberships_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_account_id ON public.memberships USING btree (account_id);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_memberships_on_user_id_and_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_user_id_and_account_id ON public.memberships USING btree (user_id, account_id);


--
-- Name: index_messages_on_chat_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_chat_id ON public.messages USING btree (chat_id);


--
-- Name: index_messages_on_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_model_id ON public.messages USING btree (model_id);


--
-- Name: index_messages_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_role ON public.messages USING btree (role);


--
-- Name: index_messages_on_tool_call_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_tool_call_id ON public.messages USING btree (tool_call_id);


--
-- Name: index_miur_adozioni_on_classe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_miur_adozioni_on_classe ON ONLY public.miur_adozioni USING btree (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina);


--
-- Name: index_miur_import_runs_on_dataset_and_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_miur_import_runs_on_dataset_and_completed_at ON public.miur_import_runs USING btree (dataset, completed_at);


--
-- Name: index_miur_scuole_on_codice_scuola; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_miur_scuole_on_codice_scuola ON ONLY public.miur_scuole USING btree (anno_scolastico, codice_scuola);


--
-- Name: index_models_on_capabilities; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_models_on_capabilities ON public.models USING gin (capabilities);


--
-- Name: index_models_on_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_models_on_family ON public.models USING btree (family);


--
-- Name: index_models_on_modalities; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_models_on_modalities ON public.models USING gin (modalities);


--
-- Name: index_models_on_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_models_on_provider ON public.models USING btree (provider);


--
-- Name: index_models_on_provider_and_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_models_on_provider_and_model_id ON public.models USING btree (provider, model_id);


--
-- Name: index_motor_alert_locks_on_alert_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_alert_locks_on_alert_id ON public.motor_alert_locks USING btree (alert_id);


--
-- Name: index_motor_alert_locks_on_alert_id_and_lock_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_motor_alert_locks_on_alert_id_and_lock_timestamp ON public.motor_alert_locks USING btree (alert_id, lock_timestamp);


--
-- Name: index_motor_alerts_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_alerts_on_query_id ON public.motor_alerts USING btree (query_id);


--
-- Name: index_motor_alerts_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_alerts_on_updated_at ON public.motor_alerts USING btree (updated_at);


--
-- Name: index_motor_audits_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_audits_on_created_at ON public.motor_audits USING btree (created_at);


--
-- Name: index_motor_audits_on_request_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_audits_on_request_uuid ON public.motor_audits USING btree (request_uuid);


--
-- Name: index_motor_configs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_motor_configs_on_key ON public.motor_configs USING btree (key);


--
-- Name: index_motor_configs_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_configs_on_updated_at ON public.motor_configs USING btree (updated_at);


--
-- Name: index_motor_dashboards_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_dashboards_on_updated_at ON public.motor_dashboards USING btree (updated_at);


--
-- Name: index_motor_forms_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_forms_on_updated_at ON public.motor_forms USING btree (updated_at);


--
-- Name: index_motor_note_tag_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_note_tag_tags_on_tag_id ON public.motor_note_tag_tags USING btree (tag_id);


--
-- Name: index_motor_queries_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_queries_on_updated_at ON public.motor_queries USING btree (updated_at);


--
-- Name: index_motor_reminders_on_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_reminders_on_scheduled_at ON public.motor_reminders USING btree (scheduled_at);


--
-- Name: index_motor_resources_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_motor_resources_on_name ON public.motor_resources USING btree (name);


--
-- Name: index_motor_resources_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_resources_on_updated_at ON public.motor_resources USING btree (updated_at);


--
-- Name: index_motor_taggable_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_motor_taggable_tags_on_tag_id ON public.motor_taggable_tags USING btree (tag_id);


--
-- Name: index_not_nows_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_not_nows_on_account_id ON public.not_nows USING btree (account_id);


--
-- Name: index_not_nows_on_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_not_nows_on_entry_id ON public.not_nows USING btree (entry_id);


--
-- Name: index_not_nows_on_not_nowable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_not_nows_on_not_nowable ON public.not_nows USING btree (not_nowable_type, not_nowable_id);


--
-- Name: index_not_nows_on_not_nowable_type_and_not_nowable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_not_nows_on_not_nowable_type_and_not_nowable_id ON public.not_nows USING btree (not_nowable_type, not_nowable_id);


--
-- Name: index_not_nows_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_not_nows_on_user_id ON public.not_nows USING btree (user_id);


--
-- Name: index_pagamenti_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagamenti_on_account_id ON public.pagamenti USING btree (account_id);


--
-- Name: index_pagamenti_on_pagabile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagamenti_on_pagabile ON public.pagamenti USING btree (pagabile_type, pagabile_id);


--
-- Name: index_pagamenti_on_pagabile_type_and_pagabile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pagamenti_on_pagabile_type_and_pagabile_id ON public.pagamenti USING btree (pagabile_type, pagabile_id);


--
-- Name: index_pagamenti_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pagamenti_on_user_id ON public.pagamenti USING btree (user_id);


--
-- Name: index_persona_classi_on_classe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_classi_on_classe_id ON public.persona_classi USING btree (classe_id);


--
-- Name: index_persona_classi_on_persona_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persona_classi_on_persona_id ON public.persona_classi USING btree (persona_id);


--
-- Name: index_persona_classi_on_persona_id_and_classe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_persona_classi_on_persona_id_and_classe_id ON public.persona_classi USING btree (persona_id, classe_id);


--
-- Name: index_personal_infos_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_personal_infos_on_user_id ON public.personal_infos USING btree (user_id);


--
-- Name: index_persone_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persone_on_account_id ON public.persone USING btree (account_id);


--
-- Name: index_persone_on_account_id_and_cognome_and_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persone_on_account_id_and_cognome_and_nome ON public.persone USING btree (account_id, cognome, nome);


--
-- Name: index_persone_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persone_on_scuola_id ON public.persone USING btree (scuola_id);


--
-- Name: index_persone_on_scuola_id_and_ruolo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_persone_on_scuola_id_and_ruolo ON public.persone USING btree (scuola_id, ruolo);


--
-- Name: index_profiles_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_profiles_on_user_id ON public.profiles USING btree (user_id);


--
-- Name: index_propagande_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_propagande_on_account_id ON public.propagande USING btree (account_id);


--
-- Name: index_propagande_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_propagande_on_user_id ON public.propagande USING btree (user_id);


--
-- Name: index_qrcodes_on_qrcodable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_qrcodes_on_qrcodable ON public.qrcodes USING btree (qrcodable_type, qrcodable_id);


--
-- Name: index_registrazioni_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_registrazioni_on_account_id ON public.registrazioni USING btree (account_id);


--
-- Name: index_registrazioni_on_registrabile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_registrazioni_on_registrabile ON public.registrazioni USING btree (registrabile_type, registrabile_id);


--
-- Name: index_registrazioni_on_registrabile_type_and_registrabile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_registrazioni_on_registrabile_type_and_registrabile_id ON public.registrazioni USING btree (registrabile_type, registrabile_id);


--
-- Name: index_registrazioni_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_registrazioni_on_user_id ON public.registrazioni USING btree (user_id);


--
-- Name: index_righe_on_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_righe_on_libro_id ON public.righe USING btree (libro_id);


--
-- Name: index_saggi_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_account_id ON public.saggi USING btree (account_id);


--
-- Name: index_saggi_on_account_id_and_stato; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_account_id_and_stato ON public.saggi USING btree (account_id, stato);


--
-- Name: index_saggi_on_documento_riga_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_documento_riga_id ON public.saggi USING btree (documento_riga_id);


--
-- Name: index_saggi_on_libro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_libro_id ON public.saggi USING btree (libro_id);


--
-- Name: index_saggi_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_scuola_id ON public.saggi USING btree (scuola_id);


--
-- Name: index_saggi_on_scuola_id_and_stato; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_scuola_id_and_stato ON public.saggi USING btree (scuola_id, stato);


--
-- Name: index_saggi_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saggi_on_user_id ON public.saggi USING btree (user_id);


--
-- Name: index_saldi_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saldi_on_account_id ON public.saldi USING btree (account_id);


--
-- Name: index_saldi_on_saldabile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saldi_on_saldabile ON public.saldi USING btree (saldabile_type, saldabile_id);


--
-- Name: index_saldi_on_saldabile_type_and_saldabile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_saldi_on_saldabile_type_and_saldabile_id ON public.saldi USING btree (saldabile_type, saldabile_id);


--
-- Name: index_scartate_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scartate_on_account_id ON public.scartate USING btree (account_id);


--
-- Name: index_scartate_on_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scartate_on_scuola_id ON public.scartate USING btree (scuola_id);


--
-- Name: index_scartate_on_scuola_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scartate_on_scuola_id_and_user_id ON public.scartate USING btree (scuola_id, user_id);


--
-- Name: index_scartate_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scartate_on_user_id ON public.scartate USING btree (user_id);


--
-- Name: index_sconti_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sconti_on_account_id ON public.sconti USING btree (account_id);


--
-- Name: index_sconti_on_categoria_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sconti_on_categoria_id ON public.sconti USING btree (categoria_id);


--
-- Name: index_sconti_on_scontabile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sconti_on_scontabile ON public.sconti USING btree (scontabile_type, scontabile_id);


--
-- Name: index_sconti_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sconti_on_user_id ON public.sconti USING btree (user_id);


--
-- Name: index_sconti_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sconti_unique ON public.sconti USING btree (user_id, scontabile_type, scontabile_id, categoria_id, data_inizio, tipo_sconto);


--
-- Name: index_scuole_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scuole_on_account_id ON public.scuole USING btree (account_id);


--
-- Name: index_scuole_on_account_id_and_codice_ministeriale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_scuole_on_account_id_and_codice_ministeriale ON public.scuole USING btree (account_id, codice_ministeriale);


--
-- Name: index_scuole_on_account_id_and_denominazione; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scuole_on_account_id_and_denominazione ON public.scuole USING btree (account_id, denominazione);


--
-- Name: index_scuole_on_account_id_and_direzione_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scuole_on_account_id_and_direzione_id ON public.scuole USING btree (account_id, direzione_id);


--
-- Name: index_scuole_on_account_id_and_posizione; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scuole_on_account_id_and_posizione ON public.scuole USING btree (account_id, posizione);


--
-- Name: index_scuole_on_account_provincia_grado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scuole_on_account_provincia_grado ON public.scuole USING btree (account_id, provincia, grado);


--
-- Name: index_scuole_on_import_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_scuole_on_import_scuola_id ON public.scuole USING btree (import_scuola_id);


--
-- Name: index_sessions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_account_id ON public.sessions USING btree (account_id);


--
-- Name: index_sessions_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sessions_on_token ON public.sessions USING btree (token);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_sessions_on_user_id_and_last_active_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id_and_last_active_at ON public.sessions USING btree (user_id, last_active_at);


--
-- Name: index_stats_on_stato; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stats_on_stato ON public.stats USING btree (stato);


--
-- Name: index_tappa_giri_on_giro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tappa_giri_on_giro_id ON public.tappa_giri USING btree (giro_id);


--
-- Name: index_tappa_giri_on_tappa_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tappa_giri_on_tappa_id ON public.tappa_giri USING btree (tappa_id);


--
-- Name: index_tappe_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tappe_on_account_id ON public.tappe USING btree (account_id);


--
-- Name: index_tappe_on_giro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tappe_on_giro_id ON public.tappe USING btree (giro_id);


--
-- Name: index_tappe_on_tappable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tappe_on_tappable ON public.tappe USING btree (tappable_type, tappable_id);


--
-- Name: index_tappe_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tappe_on_user_id ON public.tappe USING btree (user_id);


--
-- Name: index_tappe_on_user_id_and_data_tappa_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tappe_on_user_id_and_data_tappa_and_position ON public.tappe USING btree (user_id, data_tappa, "position");


--
-- Name: index_tool_calls_on_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tool_calls_on_message_id ON public.tool_calls USING btree (message_id);


--
-- Name: index_tool_calls_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tool_calls_on_name ON public.tool_calls USING btree (name);


--
-- Name: index_tool_calls_on_tool_call_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tool_calls_on_tool_call_id ON public.tool_calls USING btree (tool_call_id);


--
-- Name: index_user_scuole_on_import_scuola_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_scuole_on_import_scuola_id ON public.user_scuole USING btree (import_scuola_id);


--
-- Name: index_user_scuole_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_scuole_on_user_id ON public.user_scuole USING btree (user_id);


--
-- Name: index_user_scuole_on_user_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_scuole_on_user_id_and_position ON public.user_scuole USING btree (user_id, "position");


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_slug ON public.users USING btree (slug);


--
-- Name: index_view_classi_on_codice_ministeriale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_view_classi_on_codice_ministeriale ON public.view_classi USING btree (codice_ministeriale);


--
-- Name: index_view_classi_on_provincia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_view_classi_on_provincia ON public.view_classi USING btree (provincia);


--
-- Name: index_voice_notes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_voice_notes_on_user_id ON public.voice_notes USING btree (user_id);


--
-- Name: miur_adozioni_202425_anno_scolastico_codicescuola_annocorso_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX miur_adozioni_202425_anno_scolastico_codicescuola_annocorso_idx ON public.miur_adozioni_202425 USING btree (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina);


--
-- Name: miur_adozioni_202425_codicescuola_editore_annocorso_discipl_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202425_codicescuola_editore_annocorso_discipl_idx ON public.miur_adozioni_202425 USING btree (codicescuola) INCLUDE (editore, annocorso, disciplina) WHERE ((tipogradoscuola)::text = 'EE'::text);


--
-- Name: miur_adozioni_202425_codicescuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202425_codicescuola_idx ON public.miur_adozioni_202425 USING btree (codicescuola);


--
-- Name: miur_adozioni_202425_disciplina_annocorso_tipogradoscuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202425_disciplina_annocorso_tipogradoscuola_idx ON public.miur_adozioni_202425 USING btree (disciplina, annocorso, tipogradoscuola);


--
-- Name: miur_adozioni_202526_anno_scolastico_codicescuola_annocorso_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX miur_adozioni_202526_anno_scolastico_codicescuola_annocorso_idx ON public.miur_adozioni_202526 USING btree (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina);


--
-- Name: miur_adozioni_202526_codicescuola_editore_annocorso_discipl_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202526_codicescuola_editore_annocorso_discipl_idx ON public.miur_adozioni_202526 USING btree (codicescuola) INCLUDE (editore, annocorso, disciplina) WHERE ((tipogradoscuola)::text = 'EE'::text);


--
-- Name: miur_adozioni_202526_codicescuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202526_codicescuola_idx ON public.miur_adozioni_202526 USING btree (codicescuola);


--
-- Name: miur_adozioni_202526_disciplina_annocorso_tipogradoscuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202526_disciplina_annocorso_tipogradoscuola_idx ON public.miur_adozioni_202526 USING btree (disciplina, annocorso, tipogradoscuola);


--
-- Name: miur_adozioni_202627_classe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX miur_adozioni_202627_classe ON public.miur_adozioni_202627 USING btree (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina);


--
-- Name: miur_adozioni_202627_cod; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202627_cod ON public.miur_adozioni_202627 USING btree (codicescuola);


--
-- Name: miur_adozioni_202627_disc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202627_disc ON public.miur_adozioni_202627 USING btree (disciplina, annocorso, tipogradoscuola);


--
-- Name: miur_adozioni_202627_ee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_adozioni_202627_ee ON public.miur_adozioni_202627 USING btree (codicescuola) INCLUDE (editore, annocorso, disciplina) WHERE ((tipogradoscuola)::text = 'EE'::text);


--
-- Name: miur_scuole_202425_anno_scolastico_codice_scuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX miur_scuole_202425_anno_scolastico_codice_scuola_idx ON public.miur_scuole_202425 USING btree (anno_scolastico, codice_scuola);


--
-- Name: miur_scuole_202425_codice_scuola_regione_provincia_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_scuole_202425_codice_scuola_regione_provincia_idx ON public.miur_scuole_202425 USING btree (codice_scuola) INCLUDE (regione, provincia);


--
-- Name: miur_scuole_202425_tipo_scuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_scuole_202425_tipo_scuola_idx ON public.miur_scuole_202425 USING btree (tipo_scuola);


--
-- Name: miur_scuole_202526_anno_scolastico_codice_scuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX miur_scuole_202526_anno_scolastico_codice_scuola_idx ON public.miur_scuole_202526 USING btree (anno_scolastico, codice_scuola);


--
-- Name: miur_scuole_202526_codice_scuola_regione_provincia_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_scuole_202526_codice_scuola_regione_provincia_idx ON public.miur_scuole_202526 USING btree (codice_scuola) INCLUDE (regione, provincia);


--
-- Name: miur_scuole_202526_tipo_scuola_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_scuole_202526_tipo_scuola_idx ON public.miur_scuole_202526 USING btree (tipo_scuola);


--
-- Name: miur_scuole_202627_cod; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_scuole_202627_cod ON public.miur_scuole_202627 USING btree (codice_scuola) INCLUDE (regione, provincia);


--
-- Name: miur_scuole_202627_cs; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX miur_scuole_202627_cs ON public.miur_scuole_202627 USING btree (anno_scolastico, codice_scuola);


--
-- Name: miur_scuole_202627_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX miur_scuole_202627_tipo ON public.miur_scuole_202627 USING btree (tipo_scuola);


--
-- Name: motor_alerts_name_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_alerts_name_unique_index ON public.motor_alerts USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: motor_api_configs_name_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_api_configs_name_unique_index ON public.motor_api_configs USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: motor_auditable_associated_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_auditable_associated_index ON public.motor_audits USING btree (associated_type, associated_id);


--
-- Name: motor_auditable_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_auditable_index ON public.motor_audits USING btree (auditable_type, auditable_id, version);


--
-- Name: motor_auditable_user_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_auditable_user_index ON public.motor_audits USING btree (user_id, user_type);


--
-- Name: motor_dashboards_title_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_dashboards_title_unique_index ON public.motor_dashboards USING btree (title) WHERE (deleted_at IS NULL);


--
-- Name: motor_forms_name_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_forms_name_unique_index ON public.motor_forms USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: motor_note_tags_name_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_note_tags_name_unique_index ON public.motor_note_tags USING btree (name);


--
-- Name: motor_note_tags_note_id_tag_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_note_tags_note_id_tag_id_index ON public.motor_note_tag_tags USING btree (note_id, tag_id);


--
-- Name: motor_notes_author_id_author_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_notes_author_id_author_type_index ON public.motor_notes USING btree (author_id, author_type);


--
-- Name: motor_notes_record_id_record_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_notes_record_id_record_type_index ON public.motor_notes USING btree (record_id, record_type);


--
-- Name: motor_notifications_recipient_id_recipient_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_notifications_recipient_id_recipient_type_index ON public.motor_notifications USING btree (recipient_id, recipient_type);


--
-- Name: motor_notifications_record_id_record_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_notifications_record_id_record_type_index ON public.motor_notifications USING btree (record_id, record_type);


--
-- Name: motor_polymorphic_association_tag_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_polymorphic_association_tag_index ON public.motor_taggable_tags USING btree (taggable_id, taggable_type, tag_id);


--
-- Name: motor_queries_name_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_queries_name_unique_index ON public.motor_queries USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: motor_reminders_author_id_author_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_reminders_author_id_author_type_index ON public.motor_reminders USING btree (author_id, author_type);


--
-- Name: motor_reminders_recipient_id_recipient_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_reminders_recipient_id_recipient_type_index ON public.motor_reminders USING btree (recipient_id, recipient_type);


--
-- Name: motor_reminders_record_id_record_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX motor_reminders_record_id_record_type_index ON public.motor_reminders USING btree (record_id, record_type);


--
-- Name: motor_tags_name_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX motor_tags_name_unique_index ON public.motor_tags USING btree (name);


--
-- Name: miur_adozioni_202425_anno_scolastico_codicescuola_annocorso_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_miur_adozioni_on_classe ATTACH PARTITION public.miur_adozioni_202425_anno_scolastico_codicescuola_annocorso_idx;


--
-- Name: miur_adozioni_202425_codicescuola_editore_annocorso_discipl_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adoz_ee ATTACH PARTITION public.miur_adozioni_202425_codicescuola_editore_annocorso_discipl_idx;


--
-- Name: miur_adozioni_202425_codicescuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adozioni_codicescuola ATTACH PARTITION public.miur_adozioni_202425_codicescuola_idx;


--
-- Name: miur_adozioni_202425_disciplina_annocorso_tipogradoscuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adozioni_disc_anno_tg ATTACH PARTITION public.miur_adozioni_202425_disciplina_annocorso_tipogradoscuola_idx;


--
-- Name: miur_adozioni_202425_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.miur_adozioni_pkey ATTACH PARTITION public.miur_adozioni_202425_pkey;


--
-- Name: miur_adozioni_202526_anno_scolastico_codicescuola_annocorso_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_miur_adozioni_on_classe ATTACH PARTITION public.miur_adozioni_202526_anno_scolastico_codicescuola_annocorso_idx;


--
-- Name: miur_adozioni_202526_codicescuola_editore_annocorso_discipl_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adoz_ee ATTACH PARTITION public.miur_adozioni_202526_codicescuola_editore_annocorso_discipl_idx;


--
-- Name: miur_adozioni_202526_codicescuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adozioni_codicescuola ATTACH PARTITION public.miur_adozioni_202526_codicescuola_idx;


--
-- Name: miur_adozioni_202526_disciplina_annocorso_tipogradoscuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adozioni_disc_anno_tg ATTACH PARTITION public.miur_adozioni_202526_disciplina_annocorso_tipogradoscuola_idx;


--
-- Name: miur_adozioni_202526_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.miur_adozioni_pkey ATTACH PARTITION public.miur_adozioni_202526_pkey;


--
-- Name: miur_adozioni_202627_classe; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_miur_adozioni_on_classe ATTACH PARTITION public.miur_adozioni_202627_classe;


--
-- Name: miur_adozioni_202627_cod; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adozioni_codicescuola ATTACH PARTITION public.miur_adozioni_202627_cod;


--
-- Name: miur_adozioni_202627_disc; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adozioni_disc_anno_tg ATTACH PARTITION public.miur_adozioni_202627_disc;


--
-- Name: miur_adozioni_202627_ee; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_adoz_ee ATTACH PARTITION public.miur_adozioni_202627_ee;


--
-- Name: miur_adozioni_202627_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.miur_adozioni_pkey ATTACH PARTITION public.miur_adozioni_202627_pkey;


--
-- Name: miur_scuole_202425_anno_scolastico_codice_scuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_miur_scuole_on_codice_scuola ATTACH PARTITION public.miur_scuole_202425_anno_scolastico_codice_scuola_idx;


--
-- Name: miur_scuole_202425_codice_scuola_regione_provincia_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_scuole_cod ATTACH PARTITION public.miur_scuole_202425_codice_scuola_regione_provincia_idx;


--
-- Name: miur_scuole_202425_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.miur_scuole_pkey ATTACH PARTITION public.miur_scuole_202425_pkey;


--
-- Name: miur_scuole_202425_tipo_scuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_scuole_tipo ATTACH PARTITION public.miur_scuole_202425_tipo_scuola_idx;


--
-- Name: miur_scuole_202526_anno_scolastico_codice_scuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_miur_scuole_on_codice_scuola ATTACH PARTITION public.miur_scuole_202526_anno_scolastico_codice_scuola_idx;


--
-- Name: miur_scuole_202526_codice_scuola_regione_provincia_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_scuole_cod ATTACH PARTITION public.miur_scuole_202526_codice_scuola_regione_provincia_idx;


--
-- Name: miur_scuole_202526_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.miur_scuole_pkey ATTACH PARTITION public.miur_scuole_202526_pkey;


--
-- Name: miur_scuole_202526_tipo_scuola_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_scuole_tipo ATTACH PARTITION public.miur_scuole_202526_tipo_scuola_idx;


--
-- Name: miur_scuole_202627_cod; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_scuole_cod ATTACH PARTITION public.miur_scuole_202627_cod;


--
-- Name: miur_scuole_202627_cs; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_miur_scuole_on_codice_scuola ATTACH PARTITION public.miur_scuole_202627_cs;


--
-- Name: miur_scuole_202627_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.miur_scuole_pkey ATTACH PARTITION public.miur_scuole_202627_pkey;


--
-- Name: miur_scuole_202627_tipo; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_miur_scuole_tipo ATTACH PARTITION public.miur_scuole_202627_tipo;


--
-- Name: not_nows fk_rails_00dc32482f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.not_nows
    ADD CONSTRAINT fk_rails_00dc32482f FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: mandati fk_rails_06b0d42d90; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandati
    ADD CONSTRAINT fk_rails_06b0d42d90 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: documenti fk_rails_097b0c5f5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documenti
    ADD CONSTRAINT fk_rails_097b0c5f5f FOREIGN KEY (derivato_da_causale_id) REFERENCES public.causali(id);


--
-- Name: not_nows fk_rails_0a6b3fee08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.not_nows
    ADD CONSTRAINT fk_rails_0a6b3fee08 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: cattedra_discipline fk_rails_0c2bfe470d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cattedra_discipline
    ADD CONSTRAINT fk_rails_0c2bfe470d FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: events fk_rails_0cb5590091; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_0cb5590091 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: messages fk_rails_0f670de7ba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_0f670de7ba FOREIGN KEY (chat_id) REFERENCES public.chats(id);


--
-- Name: user_scuole fk_rails_1072eb6c37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_scuole
    ADD CONSTRAINT fk_rails_1072eb6c37 FOREIGN KEY (import_scuola_id) REFERENCES public.import_scuole(id);


--
-- Name: adozioni fk_rails_12e1444c93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni
    ADD CONSTRAINT fk_rails_12e1444c93 FOREIGN KEY (classe_id) REFERENCES public.classi(id);


--
-- Name: documenti fk_rails_1348b8d595; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documenti
    ADD CONSTRAINT fk_rails_1348b8d595 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: events fk_rails_17c5f28626; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_17c5f28626 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: chats fk_rails_1835d93df1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT fk_rails_1835d93df1 FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: mandati fk_rails_20e1e7756c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandati
    ADD CONSTRAINT fk_rails_20e1e7756c FOREIGN KEY (editore_id) REFERENCES public.editori(id);


--
-- Name: categorie fk_rails_273146033d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorie
    ADD CONSTRAINT fk_rails_273146033d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: goldnesses fk_rails_2981cd56d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goldnesses
    ADD CONSTRAINT fk_rails_2981cd56d1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: pagamenti fk_rails_2d7904678a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamenti
    ADD CONSTRAINT fk_rails_2d7904678a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: categorie fk_rails_2e4e82421d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categorie
    ADD CONSTRAINT fk_rails_2e4e82421d FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: not_nows fk_rails_336d23e383; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.not_nows
    ADD CONSTRAINT fk_rails_336d23e383 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: entries fk_rails_37a3feaeb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_37a3feaeb6 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: motor_alert_locks fk_rails_38d1b2960e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_alert_locks
    ADD CONSTRAINT fk_rails_38d1b2960e FOREIGN KEY (alert_id) REFERENCES public.motor_alerts(id);


--
-- Name: registrazioni fk_rails_3f8bf122e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registrazioni
    ADD CONSTRAINT fk_rails_3f8bf122e1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: adozioni_comunicate fk_rails_44e111a5db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni_comunicate
    ADD CONSTRAINT fk_rails_44e111a5db FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: libri fk_rails_5271b24524; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libri
    ADD CONSTRAINT fk_rails_5271b24524 FOREIGN KEY (editore_id) REFERENCES public.editori(id);


--
-- Name: messages fk_rails_552873cb52; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_552873cb52 FOREIGN KEY (tool_call_id) REFERENCES public.tool_calls(id);


--
-- Name: filters fk_rails_5715048402; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters
    ADD CONSTRAINT fk_rails_5715048402 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: motor_note_tag_tags fk_rails_5958bda098; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_note_tag_tags
    ADD CONSTRAINT fk_rails_5958bda098 FOREIGN KEY (note_id) REFERENCES public.motor_notes(id);


--
-- Name: entries fk_rails_5a6bee75e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_5a6bee75e6 FOREIGN KEY (giro_id) REFERENCES public.giri(id);


--
-- Name: sconti fk_rails_5d3aade040; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sconti
    ADD CONSTRAINT fk_rails_5d3aade040 FOREIGN KEY (categoria_id) REFERENCES public.categorie(id);


--
-- Name: account_zone fk_rails_5e5db83374; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_zone
    ADD CONSTRAINT fk_rails_5e5db83374 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: classi fk_rails_5f20b1c47e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classi
    ADD CONSTRAINT fk_rails_5f20b1c47e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: appunti fk_rails_61557e7cd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appunti
    ADD CONSTRAINT fk_rails_61557e7cd7 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: appunti fk_rails_651e9e3fa9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appunti
    ADD CONSTRAINT fk_rails_651e9e3fa9 FOREIGN KEY (voice_note_id) REFERENCES public.voice_notes(id);


--
-- Name: adozioni fk_rails_6feb4175d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni
    ADD CONSTRAINT fk_rails_6feb4175d9 FOREIGN KEY (libro_id) REFERENCES public.libri(id);


--
-- Name: scuole fk_rails_70040b189f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scuole
    ADD CONSTRAINT fk_rails_70040b189f FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: registrazioni fk_rails_723623c91d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registrazioni
    ADD CONSTRAINT fk_rails_723623c91d FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: documenti fk_rails_7b9f6f0c5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documenti
    ADD CONSTRAINT fk_rails_7b9f6f0c5d FOREIGN KEY (documento_padre_id) REFERENCES public.documenti(id);


--
-- Name: motor_alerts fk_rails_8828951644; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_alerts
    ADD CONSTRAINT fk_rails_8828951644 FOREIGN KEY (query_id) REFERENCES public.motor_queries(id);


--
-- Name: sconti fk_rails_8cac5f49c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sconti
    ADD CONSTRAINT fk_rails_8cac5f49c0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tappe fk_rails_9586fb1027; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappe
    ADD CONSTRAINT fk_rails_9586fb1027 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: tappa_giri fk_rails_978a0dc5f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappa_giri
    ADD CONSTRAINT fk_rails_978a0dc5f9 FOREIGN KEY (giro_id) REFERENCES public.giri(id);


--
-- Name: adozioni fk_rails_984cdac748; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adozioni
    ADD CONSTRAINT fk_rails_984cdac748 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: libri fk_rails_9986b50b87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libri
    ADD CONSTRAINT fk_rails_9986b50b87 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: entries fk_rails_99dc12d4fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_99dc12d4fd FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: scuole fk_rails_9be4d88132; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scuole
    ADD CONSTRAINT fk_rails_9be4d88132 FOREIGN KEY (import_scuola_id) REFERENCES public.import_scuole(id);


--
-- Name: tool_calls fk_rails_9c8daee481; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tool_calls
    ADD CONSTRAINT fk_rails_9c8daee481 FOREIGN KEY (message_id) REFERENCES public.messages(id);


--
-- Name: user_scuole fk_rails_9d3c48e187; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_scuole
    ADD CONSTRAINT fk_rails_9d3c48e187 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: giri fk_rails_a05e53a400; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giri
    ADD CONSTRAINT fk_rails_a05e53a400 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: filters fk_rails_b3b93a712a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters
    ADD CONSTRAINT fk_rails_b3b93a712a FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: libri fk_rails_b67222e89b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.libri
    ADD CONSTRAINT fk_rails_b67222e89b FOREIGN KEY (categoria_id) REFERENCES public.categorie(id);


--
-- Name: righe fk_rails_b790aa574f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.righe
    ADD CONSTRAINT fk_rails_b790aa574f FOREIGN KEY (libro_id) REFERENCES public.libri(id);


--
-- Name: persone fk_rails_b7aecc56e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT fk_rails_b7aecc56e6 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: goldnesses fk_rails_b8b1802a5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goldnesses
    ADD CONSTRAINT fk_rails_b8b1802a5b FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: entries fk_rails_b9b1e0947e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entries
    ADD CONSTRAINT fk_rails_b9b1e0947e FOREIGN KEY (column_id) REFERENCES public.columns(id);


--
-- Name: motor_taggable_tags fk_rails_ba9ebe2280; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_taggable_tags
    ADD CONSTRAINT fk_rails_ba9ebe2280 FOREIGN KEY (tag_id) REFERENCES public.motor_tags(id);


--
-- Name: events fk_rails_bc79446531; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_bc79446531 FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: messages fk_rails_c02b47ad97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_c02b47ad97 FOREIGN KEY (model_id) REFERENCES public.models(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: consegne fk_rails_c5de7f38a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consegne
    ADD CONSTRAINT fk_rails_c5de7f38a3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: consegne fk_rails_c8d45caf1a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consegne
    ADD CONSTRAINT fk_rails_c8d45caf1a FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: classi fk_rails_d5795a14a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classi
    ADD CONSTRAINT fk_rails_d5795a14a5 FOREIGN KEY (scuola_id) REFERENCES public.scuole(id);


--
-- Name: voice_notes fk_rails_d76d2c5161; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voice_notes
    ADD CONSTRAINT fk_rails_d76d2c5161 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: chats fk_rails_d77f0cc6f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT fk_rails_d77f0cc6f9 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: goldnesses fk_rails_dbf173bc6e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goldnesses
    ADD CONSTRAINT fk_rails_dbf173bc6e FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: tappe fk_rails_def93d3e7b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappe
    ADD CONSTRAINT fk_rails_def93d3e7b FOREIGN KEY (giro_id) REFERENCES public.giri(id);


--
-- Name: documenti fk_rails_dfb7920d33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documenti
    ADD CONSTRAINT fk_rails_dfb7920d33 FOREIGN KEY (causale_id) REFERENCES public.causali(id);


--
-- Name: sconti fk_rails_e0082fd386; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sconti
    ADD CONSTRAINT fk_rails_e0082fd386 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: columns fk_rails_e113c0c465; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.columns
    ADD CONSTRAINT fk_rails_e113c0c465 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: giri fk_rails_e2c7f7ed1f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.giri
    ADD CONSTRAINT fk_rails_e2c7f7ed1f FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: profiles fk_rails_e424190865; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT fk_rails_e424190865 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: chats fk_rails_e555f43151; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT fk_rails_e555f43151 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: closures fk_rails_ef566f346f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.closures
    ADD CONSTRAINT fk_rails_ef566f346f FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: motor_note_tag_tags fk_rails_f0bd88b67d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.motor_note_tag_tags
    ADD CONSTRAINT fk_rails_f0bd88b67d FOREIGN KEY (tag_id) REFERENCES public.motor_note_tags(id);


--
-- Name: tappe fk_rails_f261625ea2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tappe
    ADD CONSTRAINT fk_rails_f261625ea2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: pagamenti fk_rails_f536618ef0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pagamenti
    ADD CONSTRAINT fk_rails_f536618ef0 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: closures fk_rails_f824ba796e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.closures
    ADD CONSTRAINT fk_rails_f824ba796e FOREIGN KEY (entry_id) REFERENCES public.entries(id);


--
-- Name: persone fk_rails_fc9cee1af4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.persone
    ADD CONSTRAINT fk_rails_fc9cee1af4 FOREIGN KEY (scuola_id) REFERENCES public.scuole(id);


--
-- Name: closures fk_rails_ff31bb0767; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.closures
    ADD CONSTRAINT fk_rails_ff31bb0767 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260706130000'),
('20260706120000'),
('20260706110000'),
('20260706104439'),
('20260706103351'),
('20260704080000'),
('20260630071728'),
('20260628175900'),
('20260617000001'),
('20260614110612'),
('20260608160000'),
('20260608120000'),
('20260605044000'),
('20260524080611'),
('20260510083008'),
('20260506115637'),
('20260506072210'),
('20260502100000'),
('20260429185901'),
('20260422142901'),
('20260422100000'),
('20260422080000'),
('20260421220000'),
('20260416092043'),
('20260412222458'),
('20260403060102'),
('20260401225246'),
('20260401225039'),
('20260324171824'),
('20260319191950'),
('20260319185835'),
('20260314073530'),
('20260312173408'),
('20260312172234'),
('20260312171504'),
('20260310232506'),
('20260309220440'),
('20260308203409'),
('20260308203050'),
('20260308170000'),
('20260308162914'),
('20260308162913'),
('20260308162912'),
('20260308162911'),
('20260308114242'),
('20260307162002'),
('20260303113705'),
('20260302094813'),
('20260228191339'),
('20260227101638'),
('20260224111946'),
('20260224092924'),
('20260224092119'),
('20260222084055'),
('20260221154509'),
('20260220174227'),
('20260220154007'),
('20260220085914'),
('20260219150103'),
('20260218140339'),
('20260218111043'),
('20260214081429'),
('20260214071623'),
('20260213174835'),
('20260212174035'),
('20260212152952'),
('20260212145522'),
('20260212093457'),
('20260212092043'),
('20260211100002'),
('20260211100001'),
('20260211100000'),
('20260211094716'),
('20260208095832'),
('20260205093608'),
('20260203204036'),
('20260131134041'),
('20260130110138'),
('20260130092159'),
('20260130092157'),
('20260130085010'),
('20260130083649'),
('20260130082552'),
('20260129102138'),
('20260126144913'),
('20260126141155'),
('20260126141104'),
('20260126140957'),
('20260126140940'),
('20260125113809'),
('20260125101221'),
('20260125101037'),
('20260124150000'),
('20260124110850'),
('20260122170000'),
('20260122081050'),
('20260121130917'),
('20260121130004'),
('20260120100006'),
('20260120100005'),
('20260120100004'),
('20260120100003'),
('20260120100002'),
('20260120100001'),
('20260115144338'),
('20260115065006'),
('20260114192453'),
('20260114181426'),
('20260114181336'),
('20260112165305'),
('20260112142937'),
('20260112142700'),
('20260112142605'),
('20260112124200'),
('20260112124100'),
('20260112124000'),
('20260112123500'),
('20260112122937'),
('20260112122857'),
('20260112122724'),
('20260112122641'),
('20260112121256'),
('20260112121206'),
('20260110111206'),
('20260110110517'),
('20260110105419'),
('20260110103800'),
('20260110103208'),
('20260109100000'),
('20260109000000'),
('20260108235000'),
('20260108230000'),
('20260108160200'),
('20260108160100'),
('20260108160000'),
('20260108155149'),
('20260108140028'),
('20260108135838'),
('20260108135750'),
('20260108135446'),
('20251108181331'),
('20251015182444'),
('20251011104245'),
('20251010173758'),
('20251010165951'),
('20251010165925'),
('20251009064808'),
('20251007114912'),
('20251007114845'),
('20251007114831'),
('20251007075744'),
('20251007075739'),
('20251007070547'),
('20251007070542'),
('20251007070537'),
('20251007070533'),
('20251003090128'),
('20251001120000'),
('20250930164358'),
('20250930164312'),
('20250929053103'),
('20250929053102'),
('20250823175609'),
('20250820062347'),
('20250615162412'),
('20250603213153'),
('20250603185738'),
('20250603185737'),
('20250501163906'),
('20250501163905'),
('20250501163904'),
('20250403190750'),
('20250306113023'),
('20250226114517'),
('20250214204949'),
('20250210174845'),
('20250126173823'),
('20250124180000'),
('20250115120000'),
('20250115000000'),
('20250104182923'),
('20250102082718'),
('20241220184452'),
('20241219165617'),
('20241219162325'),
('20241208084802'),
('20241208075854'),
('20241206204219'),
('20241206185716'),
('20241202102839'),
('20241201082827'),
('20241130160738'),
('20241114171532'),
('20241114171510'),
('20241109174216'),
('20241109155158'),
('20241109155127'),
('20241109132054'),
('20241109131955'),
('20241109131935'),
('20241109105342'),
('20241030092046'),
('20241025183204'),
('20241019174853'),
('20241019120951'),
('20241019102859'),
('20241017055148'),
('20241016154901'),
('20241013034645'),
('20240918075333'),
('20240731105619'),
('20240716105104'),
('20240714085800'),
('20240713084241'),
('20240710044911'),
('20240709195149'),
('20240709184307'),
('20240629101242'),
('20240624194604'),
('20240615145225'),
('20240607173309'),
('20240604043619'),
('20240519182547'),
('20240508185111'),
('20240506134559'),
('20240427142914'),
('20240427130556'),
('20240427121411'),
('20240424113238'),
('20240423164829'),
('20240423131700'),
('20240416162502'),
('20240416161217'),
('20240412161615'),
('20240324083728'),
('20240323111334'),
('20240305103324'),
('20240305100527'),
('20240304152634'),
('20240224121929'),
('20240222134152'),
('20240222125627'),
('20240222062400'),
('20240219141955'),
('20240215095024'),
('20240214155443'),
('20240213054648'),
('20240212165104'),
('20240212065036'),
('20240207181830'),
('20240207180243'),
('20240129144639'),
('20240123174048'),
('20240123173840'),
('20240118193908'),
('20240116130143'),
('20240116122041'),
('20240111124950'),
('20240110180328'),
('20240106104325'),
('20231228132228'),
('20231220170700'),
('20231212112141'),
('20231212112130'),
('20231208145400'),
('20231202073600'),
('20231130133705'),
('20231130132049'),
('20231130132000');

