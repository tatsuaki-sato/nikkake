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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_digest character varying NOT NULL,
    device_label character varying,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
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
-- Name: exercise_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exercise_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    routine_log_id uuid NOT NULL,
    routine_exercise_id uuid,
    exercise_id uuid NOT NULL,
    set_number integer NOT NULL,
    actual_reps integer,
    actual_weight double precision,
    actual_duration_sec integer,
    notes text,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: exercises; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exercises (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    category character varying NOT NULL,
    description text,
    icon character varying,
    is_preset boolean DEFAULT false NOT NULL,
    created_by_id uuid,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT exercises_category_check CHECK (((category)::text = ANY ((ARRAY['strength'::character varying, 'cardio'::character varying, 'game'::character varying, 'custom'::character varying])::text[])))
);


--
-- Name: mutation_receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mutation_receipts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    key character varying NOT NULL,
    mutation character varying NOT NULL,
    response jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: routine_exercises; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routine_exercises (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    routine_id uuid NOT NULL,
    exercise_id uuid NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    target_sets integer DEFAULT 3 NOT NULL,
    target_reps integer,
    target_weight double precision,
    target_duration_sec integer,
    rest_sec integer,
    notes text,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: routine_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routine_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    routine_id uuid NOT NULL,
    log_date date NOT NULL,
    status character varying NOT NULL,
    duration_sec integer,
    notes text,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    client_time_zone character varying,
    client_utc_offset_minutes integer,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT routine_logs_status_check CHECK (((status)::text = ANY ((ARRAY['completed'::character varying, 'partial'::character varying, 'skipped'::character varying])::text[])))
);


--
-- Name: routines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    color character varying DEFAULT '#6C5CE7'::character varying NOT NULL,
    icon character varying DEFAULT '💪'::character varying NOT NULL,
    frequency_type character varying DEFAULT 'daily'::character varying NOT NULL,
    frequency_value integer DEFAULT 1 NOT NULL,
    frequency_days integer[] DEFAULT '{}'::integer[] NOT NULL,
    preferred_time time without time zone,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    deleted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT routines_frequency_type_check CHECK (((frequency_type)::text = ANY ((ARRAY['daily'::character varying, 'every_n_days'::character varying, 'weekly'::character varying])::text[])))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email public.citext,
    password_digest character varying,
    display_name character varying,
    email_verified_at timestamp(6) without time zone,
    time_zone character varying DEFAULT 'Asia/Tokyo'::character varying NOT NULL,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: exercise_logs exercise_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercise_logs
    ADD CONSTRAINT exercise_logs_pkey PRIMARY KEY (id);


--
-- Name: exercises exercises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercises
    ADD CONSTRAINT exercises_pkey PRIMARY KEY (id);


--
-- Name: mutation_receipts mutation_receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mutation_receipts
    ADD CONSTRAINT mutation_receipts_pkey PRIMARY KEY (id);


--
-- Name: routine_exercises routine_exercises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_exercises
    ADD CONSTRAINT routine_exercises_pkey PRIMARY KEY (id);


--
-- Name: routine_logs routine_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_logs
    ADD CONSTRAINT routine_logs_pkey PRIMARY KEY (id);


--
-- Name: routines routines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routines
    ADD CONSTRAINT routines_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_api_tokens_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_tokens_on_token_digest ON public.api_tokens USING btree (token_digest);


--
-- Name: index_api_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_user_id ON public.api_tokens USING btree (user_id);


--
-- Name: index_exercise_logs_on_exercise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercise_logs_on_exercise_id ON public.exercise_logs USING btree (exercise_id);


--
-- Name: index_exercise_logs_on_routine_exercise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercise_logs_on_routine_exercise_id ON public.exercise_logs USING btree (routine_exercise_id);


--
-- Name: index_exercise_logs_on_routine_log_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercise_logs_on_routine_log_id ON public.exercise_logs USING btree (routine_log_id);


--
-- Name: index_exercise_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercise_logs_on_user_id ON public.exercise_logs USING btree (user_id);


--
-- Name: index_exercise_logs_on_user_id_and_exercise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercise_logs_on_user_id_and_exercise_id ON public.exercise_logs USING btree (user_id, exercise_id);


--
-- Name: index_exercise_logs_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercise_logs_on_user_id_and_updated_at ON public.exercise_logs USING btree (user_id, updated_at);


--
-- Name: index_exercises_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercises_on_created_by_id ON public.exercises USING btree (created_by_id);


--
-- Name: index_exercises_on_is_preset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercises_on_is_preset ON public.exercises USING btree (is_preset);


--
-- Name: index_exercises_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exercises_on_updated_at ON public.exercises USING btree (updated_at);


--
-- Name: index_mutation_receipts_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mutation_receipts_on_created_at ON public.mutation_receipts USING btree (created_at);


--
-- Name: index_mutation_receipts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mutation_receipts_on_user_id ON public.mutation_receipts USING btree (user_id);


--
-- Name: index_mutation_receipts_on_user_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mutation_receipts_on_user_id_and_key ON public.mutation_receipts USING btree (user_id, key);


--
-- Name: index_routine_exercises_on_exercise_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_exercises_on_exercise_id ON public.routine_exercises USING btree (exercise_id);


--
-- Name: index_routine_exercises_on_routine_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_exercises_on_routine_id ON public.routine_exercises USING btree (routine_id);


--
-- Name: index_routine_exercises_on_routine_id_and_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_exercises_on_routine_id_and_sort_order ON public.routine_exercises USING btree (routine_id, sort_order) WHERE (deleted_at IS NULL);


--
-- Name: index_routine_exercises_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_exercises_on_user_id ON public.routine_exercises USING btree (user_id);


--
-- Name: index_routine_exercises_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_exercises_on_user_id_and_updated_at ON public.routine_exercises USING btree (user_id, updated_at);


--
-- Name: index_routine_logs_on_routine_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_logs_on_routine_id ON public.routine_logs USING btree (routine_id);


--
-- Name: index_routine_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_logs_on_user_id ON public.routine_logs USING btree (user_id);


--
-- Name: index_routine_logs_on_user_id_and_log_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_logs_on_user_id_and_log_date ON public.routine_logs USING btree (user_id, log_date) WHERE (deleted_at IS NULL);


--
-- Name: index_routine_logs_on_user_id_and_routine_id_and_log_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_logs_on_user_id_and_routine_id_and_log_date ON public.routine_logs USING btree (user_id, routine_id, log_date);


--
-- Name: index_routine_logs_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routine_logs_on_user_id_and_updated_at ON public.routine_logs USING btree (user_id, updated_at);


--
-- Name: index_routines_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routines_on_user_id ON public.routines USING btree (user_id);


--
-- Name: index_routines_on_user_id_and_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routines_on_user_id_and_sort_order ON public.routines USING btree (user_id, sort_order) WHERE (deleted_at IS NULL);


--
-- Name: index_routines_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_routines_on_user_id_and_updated_at ON public.routines USING btree (user_id, updated_at);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email) WHERE (email IS NOT NULL);


--
-- Name: index_users_on_last_seen_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_seen_at ON public.users USING btree (last_seen_at) WHERE (email IS NULL);


--
-- Name: exercise_logs fk_rails_1fdddabd2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercise_logs
    ADD CONSTRAINT fk_rails_1fdddabd2b FOREIGN KEY (routine_exercise_id) REFERENCES public.routine_exercises(id) ON DELETE SET NULL;


--
-- Name: exercise_logs fk_rails_2d20b50904; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercise_logs
    ADD CONSTRAINT fk_rails_2d20b50904 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: routines fk_rails_6d925cab08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routines
    ADD CONSTRAINT fk_rails_6d925cab08 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: routine_exercises fk_rails_86f0b0200b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_exercises
    ADD CONSTRAINT fk_rails_86f0b0200b FOREIGN KEY (exercise_id) REFERENCES public.exercises(id);


--
-- Name: routine_logs fk_rails_895b697f82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_logs
    ADD CONSTRAINT fk_rails_895b697f82 FOREIGN KEY (routine_id) REFERENCES public.routines(id);


--
-- Name: exercise_logs fk_rails_8c417d8fcd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercise_logs
    ADD CONSTRAINT fk_rails_8c417d8fcd FOREIGN KEY (routine_log_id) REFERENCES public.routine_logs(id);


--
-- Name: routine_exercises fk_rails_8d726adbee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_exercises
    ADD CONSTRAINT fk_rails_8d726adbee FOREIGN KEY (routine_id) REFERENCES public.routines(id);


--
-- Name: mutation_receipts fk_rails_9ad3169901; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mutation_receipts
    ADD CONSTRAINT fk_rails_9ad3169901 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: routine_exercises fk_rails_9b0064e36a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_exercises
    ADD CONSTRAINT fk_rails_9b0064e36a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: exercise_logs fk_rails_c1aea2d8c9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercise_logs
    ADD CONSTRAINT fk_rails_c1aea2d8c9 FOREIGN KEY (exercise_id) REFERENCES public.exercises(id);


--
-- Name: routine_logs fk_rails_e1786439f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routine_logs
    ADD CONSTRAINT fk_rails_e1786439f7 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: exercises fk_rails_ebb9a79285; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exercises
    ADD CONSTRAINT fk_rails_ebb9a79285 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: api_tokens fk_rails_f16b5e0447; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT fk_rails_f16b5e0447 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260802010602');

