--
-- PostgreSQL database dump
--

-- Dumped from database version 12.13
-- Dumped by pg_dump version 13.8 (Debian 13.8-0+deb11u1)

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
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: oban_jobs_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oban_jobs_notify() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  channel text;
  notice json;
BEGIN
  IF NEW.state = 'available' THEN
    channel = 'public.oban_insert';
    notice = json_build_object('queue', NEW.queue);

    PERFORM pg_notify(channel, notice::text);
  END IF;

  RETURN NULL;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: brainstorming_moderating_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brainstorming_moderating_users (
    brainstorming_id uuid NOT NULL,
    user_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: brainstorming_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brainstorming_users (
    id uuid NOT NULL,
    brainstorming_id uuid,
    user_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: brainstormings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brainstormings (
    id uuid NOT NULL,
    name character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    admin_url_id uuid,
    option_show_link_to_settings boolean DEFAULT true
);


--
-- Name: idea_idea_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.idea_idea_labels (
    idea_id uuid NOT NULL,
    idea_label_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: idea_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.idea_labels (
    id uuid NOT NULL,
    name character varying(255),
    color character varying(255),
    position_order integer,
    brainstorming_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: ideas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ideas (
    id uuid NOT NULL,
    username character varying(255),
    brainstorming_id uuid,
    body character varying(1024),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    label text,
    label_id uuid,
    user_id uuid
);


--
-- Name: inspirations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inspirations (
    id uuid NOT NULL,
    title character varying(1024),
    language character varying(6),
    type character varying(128),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.likes (
    id uuid NOT NULL,
    idea_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    user_id uuid
);


--
-- Name: links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.links (
    id uuid NOT NULL,
    url text,
    title text,
    description text,
    img_preview_url text,
    idea_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags character varying(255)[] DEFAULT ARRAY[]::character varying[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT priority_range CHECK (((priority >= 0) AND (priority <= 3))),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oban_jobs IS '11';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: -
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    username character varying(64)
);


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: brainstorming_moderating_users brainstorming_moderating_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstorming_moderating_users
    ADD CONSTRAINT brainstorming_moderating_users_pkey PRIMARY KEY (brainstorming_id, user_id);


--
-- Name: brainstorming_users brainstorming_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstorming_users
    ADD CONSTRAINT brainstorming_users_pkey PRIMARY KEY (id);


--
-- Name: brainstormings brainstormings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstormings
    ADD CONSTRAINT brainstormings_pkey PRIMARY KEY (id);


--
-- Name: idea_idea_labels idea_idea_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idea_idea_labels
    ADD CONSTRAINT idea_idea_labels_pkey PRIMARY KEY (idea_id, idea_label_id);


--
-- Name: idea_labels idea_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idea_labels
    ADD CONSTRAINT idea_labels_pkey PRIMARY KEY (id);


--
-- Name: ideas ideas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_pkey PRIMARY KEY (id);


--
-- Name: inspirations inspirations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inspirations
    ADD CONSTRAINT inspirations_pkey PRIMARY KEY (id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (id);


--
-- Name: links links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.links
    ADD CONSTRAINT links_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


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
-- Name: brainstorming_moderating_users_brainstorming_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brainstorming_moderating_users_brainstorming_id_index ON public.brainstorming_moderating_users USING btree (brainstorming_id);


--
-- Name: brainstorming_moderating_users_brainstorming_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX brainstorming_moderating_users_brainstorming_id_user_id_index ON public.brainstorming_moderating_users USING btree (brainstorming_id, user_id);


--
-- Name: brainstorming_moderating_users_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brainstorming_moderating_users_user_id_index ON public.brainstorming_moderating_users USING btree (user_id);


--
-- Name: brainstorming_users_brainstorming_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brainstorming_users_brainstorming_id_index ON public.brainstorming_users USING btree (brainstorming_id);


--
-- Name: brainstorming_users_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brainstorming_users_user_id_index ON public.brainstorming_users USING btree (user_id);


--
-- Name: idea_idea_labels_idea_id_idea_label_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idea_idea_labels_idea_id_idea_label_id_index ON public.idea_idea_labels USING btree (idea_id, idea_label_id);


--
-- Name: idea_idea_labels_idea_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idea_idea_labels_idea_id_index ON public.idea_idea_labels USING btree (idea_id);


--
-- Name: idea_idea_labels_idea_label_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idea_idea_labels_idea_label_id_index ON public.idea_idea_labels USING btree (idea_label_id);


--
-- Name: idea_labels_brainstorming_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idea_labels_brainstorming_id_index ON public.idea_labels USING btree (brainstorming_id);


--
-- Name: inspirations_title_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX inspirations_title_index ON public.inspirations USING btree (title);


--
-- Name: likes_idea_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX likes_idea_id_index ON public.likes USING btree (idea_id);


--
-- Name: likes_idea_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX likes_idea_id_user_id_index ON public.likes USING btree (idea_id, user_id);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: oban_jobs oban_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER oban_notify AFTER INSERT ON public.oban_jobs FOR EACH ROW EXECUTE FUNCTION public.oban_jobs_notify();


--
-- Name: brainstorming_moderating_users brainstorming_moderating_users_brainstorming_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstorming_moderating_users
    ADD CONSTRAINT brainstorming_moderating_users_brainstorming_id_fkey FOREIGN KEY (brainstorming_id) REFERENCES public.brainstormings(id) ON DELETE CASCADE;


--
-- Name: brainstorming_moderating_users brainstorming_moderating_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstorming_moderating_users
    ADD CONSTRAINT brainstorming_moderating_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: brainstorming_users brainstorming_users_brainstorming_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstorming_users
    ADD CONSTRAINT brainstorming_users_brainstorming_id_fkey FOREIGN KEY (brainstorming_id) REFERENCES public.brainstormings(id) ON DELETE CASCADE;


--
-- Name: brainstorming_users brainstorming_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brainstorming_users
    ADD CONSTRAINT brainstorming_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: idea_idea_labels idea_idea_labels_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idea_idea_labels
    ADD CONSTRAINT idea_idea_labels_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(id) ON DELETE CASCADE;


--
-- Name: idea_idea_labels idea_idea_labels_idea_label_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idea_idea_labels
    ADD CONSTRAINT idea_idea_labels_idea_label_id_fkey FOREIGN KEY (idea_label_id) REFERENCES public.idea_labels(id);


--
-- Name: idea_labels idea_labels_brainstorming_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idea_labels
    ADD CONSTRAINT idea_labels_brainstorming_id_fkey FOREIGN KEY (brainstorming_id) REFERENCES public.brainstormings(id) ON DELETE CASCADE;


--
-- Name: ideas ideas_brainstorming_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_brainstorming_id_fkey FOREIGN KEY (brainstorming_id) REFERENCES public.brainstormings(id) ON DELETE CASCADE;


--
-- Name: ideas ideas_label_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_label_id_fkey FOREIGN KEY (label_id) REFERENCES public.idea_labels(id);


--
-- Name: ideas ideas_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: likes likes_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(id) ON DELETE CASCADE;


--
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: links links_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.links
    ADD CONSTRAINT links_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20201207175133);
INSERT INTO public."schema_migrations" (version) VALUES (20201212124439);
INSERT INTO public."schema_migrations" (version) VALUES (20201212132557);
INSERT INTO public."schema_migrations" (version) VALUES (20201218144810);
INSERT INTO public."schema_migrations" (version) VALUES (20201220111148);
INSERT INTO public."schema_migrations" (version) VALUES (20201229121246);
INSERT INTO public."schema_migrations" (version) VALUES (20201231143934);
INSERT INTO public."schema_migrations" (version) VALUES (20201231144053);
INSERT INTO public."schema_migrations" (version) VALUES (20210111151706);
INSERT INTO public."schema_migrations" (version) VALUES (20210111202252);
INSERT INTO public."schema_migrations" (version) VALUES (20210112200831);
INSERT INTO public."schema_migrations" (version) VALUES (20210114133116);
INSERT INTO public."schema_migrations" (version) VALUES (20210115114944);
INSERT INTO public."schema_migrations" (version) VALUES (20210124094443);
INSERT INTO public."schema_migrations" (version) VALUES (20210127203125);
INSERT INTO public."schema_migrations" (version) VALUES (20210306141634);
INSERT INTO public."schema_migrations" (version) VALUES (20210307073759);
INSERT INTO public."schema_migrations" (version) VALUES (20210313121036);
INSERT INTO public."schema_migrations" (version) VALUES (20210313172908);
INSERT INTO public."schema_migrations" (version) VALUES (20210314114416);
INSERT INTO public."schema_migrations" (version) VALUES (20210320072725);
INSERT INTO public."schema_migrations" (version) VALUES (20220220151400);
INSERT INTO public."schema_migrations" (version) VALUES (20220220162733);
INSERT INTO public."schema_migrations" (version) VALUES (20221102094926);
INSERT INTO public."schema_migrations" (version) VALUES (20221220151400);
