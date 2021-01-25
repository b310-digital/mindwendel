--
-- PostgreSQL database dump
--

-- Dumped from database version 12.5 (Ubuntu 12.5-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.5 (Ubuntu 12.5-0ubuntu0.20.04.1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

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
    admin_url_id uuid
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
-- Name: ideas ideas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_pkey PRIMARY KEY (id);


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
-- Name: brainstorming_users_brainstorming_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brainstorming_users_brainstorming_id_index ON public.brainstorming_users USING btree (brainstorming_id);


--
-- Name: brainstorming_users_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX brainstorming_users_user_id_index ON public.brainstorming_users USING btree (user_id);


--
-- Name: likes_idea_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX likes_idea_id_index ON public.likes USING btree (idea_id);


--
-- Name: likes_idea_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX likes_idea_id_user_id_index ON public.likes USING btree (idea_id, user_id);


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
-- Name: ideas ideas_brainstorming_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_brainstorming_id_fkey FOREIGN KEY (brainstorming_id) REFERENCES public.brainstormings(id) ON DELETE CASCADE;


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
