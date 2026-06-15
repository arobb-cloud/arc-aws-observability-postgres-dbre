--
-- PostgreSQL database dump
--

\restrict NtT9wz7XAVXAvSXoei90UNt3iLifrv9Cyp9qVOcUCeZfjAOhR95UjDzUTi5ScWl

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

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
-- Name: app; Type: SCHEMA; Schema: -; Owner: appuser
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO appuser;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: health_check; Type: TABLE; Schema: app; Owner: appuser
--

CREATE TABLE app.health_check (
    id integer NOT NULL,
    status text NOT NULL,
    checked_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE app.health_check OWNER TO appuser;

--
-- Name: health_check_id_seq; Type: SEQUENCE; Schema: app; Owner: appuser
--

CREATE SEQUENCE app.health_check_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE app.health_check_id_seq OWNER TO appuser;

--
-- Name: health_check_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: appuser
--

ALTER SEQUENCE app.health_check_id_seq OWNED BY app.health_check.id;


--
-- Name: health_check id; Type: DEFAULT; Schema: app; Owner: appuser
--

ALTER TABLE ONLY app.health_check ALTER COLUMN id SET DEFAULT nextval('app.health_check_id_seq'::regclass);


--
-- Data for Name: health_check; Type: TABLE DATA; Schema: app; Owner: appuser
--

COPY app.health_check (id, status, checked_at) FROM stdin;
1	PostgreSQL initialized successfully	2026-06-11 18:26:51.968863
2	Recovery validation test number 1	2026-06-14 23:57:16.837741
\.


--
-- Name: health_check_id_seq; Type: SEQUENCE SET; Schema: app; Owner: appuser
--

SELECT pg_catalog.setval('app.health_check_id_seq', 2, true);


--
-- Name: health_check health_check_pkey; Type: CONSTRAINT; Schema: app; Owner: appuser
--

ALTER TABLE ONLY app.health_check
    ADD CONSTRAINT health_check_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict NtT9wz7XAVXAvSXoei90UNt3iLifrv9Cyp9qVOcUCeZfjAOhR95UjDzUTi5ScWl

