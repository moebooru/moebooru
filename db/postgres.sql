--
-- PostgreSQL database dump
--

SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'Standard public schema';


--
-- Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: -
--

CREATE PROCEDURAL LANGUAGE plpgsql;


SET search_path = public, pg_catalog;

--
-- Name: trg_posts__delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts__delete() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE table_data SET row_count = row_count - 1 WHERE name = 'posts';
	RETURN OLD;
END;
$$
    LANGUAGE plpgsql;


--
-- Name: trg_posts__insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts__insert() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE table_data SET row_count = row_count + 1 WHERE name = 'posts';
	RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


--
-- Name: trg_posts_tags__delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts_tags__delete() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE tags SET post_count = post_count - 1 WHERE tags.id = OLD.tag_id;
	RETURN OLD;
END;
$$
    LANGUAGE plpgsql;


--
-- Name: trg_posts_tags__insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts_tags__insert() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE tags SET post_count = post_count + 1 WHERE tags.id = NEW.tag_id;
	RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


--
-- Name: trg_users__delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_users__delete() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE table_data SET row_count = row_count - 1 WHERE name = 'users';
	RETURN OLD;
END;
$$
    LANGUAGE plpgsql;


--
-- Name: trg_users__insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_users__insert() RETURNS "trigger"
    AS $$
BEGIN
	UPDATE table_data SET row_count = row_count + 1 WHERE name = 'users';
	RETURN NEW;
END;
$$
    LANGUAGE plpgsql;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comments (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    post_id integer NOT NULL,
    user_id integer,
    body text NOT NULL,
    ip_addr text NOT NULL,
    signal_level smallint DEFAULT 1 NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comments_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE favorites (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE favorites_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE favorites_id_seq OWNED BY favorites.id;


--
-- Name: note_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE note_versions (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    body text NOT NULL,
    version integer NOT NULL,
    ip_addr text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    note_id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer
);


--
-- Name: note_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE note_versions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: note_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE note_versions_id_seq OWNED BY note_versions.id;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notes (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    ip_addr text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    post_id integer NOT NULL,
    body text NOT NULL
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notes_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notes_id_seq OWNED BY notes.id;


--
-- Name: post_tag_histories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_tag_histories (
    id integer NOT NULL,
    post_id integer NOT NULL,
    tags text NOT NULL
);


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_tag_histories_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_tag_histories_id_seq OWNED BY post_tag_histories.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    user_id integer,
    score integer DEFAULT 0 NOT NULL,
    source text NOT NULL,
    md5 text NOT NULL,
    last_commented_at timestamp without time zone,
    rating character(1) DEFAULT 'q'::bpchar NOT NULL,
    width integer,
    height integer,
    is_warehoused boolean DEFAULT false NOT NULL,
    last_voter_ip text,
    ip_addr text NOT NULL,
    cached_tags text DEFAULT ''::text NOT NULL,
    is_note_locked boolean DEFAULT false NOT NULL,
    fav_count integer DEFAULT 0 NOT NULL,
    file_ext text DEFAULT ''::text NOT NULL,
    last_noted_at timestamp without time zone,
	is_rating_locked boolean DEFAULT false NOT NULL
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE posts_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: posts_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts_tags (
    post_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: table_data; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE table_data (
    name text NOT NULL,
    row_count integer NOT NULL
);


--
-- Name: tag_aliases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_aliases (
    id integer NOT NULL,
    name text NOT NULL,
    alias_id integer NOT NULL
);


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_aliases_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tag_aliases_id_seq OWNED BY tag_aliases.id;


--
-- Name: tag_implications; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_implications (
    id integer NOT NULL,
    parent_id integer NOT NULL,
    child_id integer NOT NULL
);


--
-- Name: tag_implications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_implications_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tag_implications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tag_implications_id_seq OWNED BY tag_implications.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tags (
    id integer NOT NULL,
    name text NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    cached_related text DEFAULT '[]'::text NOT NULL,
    cached_related_expires_on timestamp without time zone DEFAULT now() NOT NULL,
    tag_type smallint DEFAULT 0 NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tags_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tags_id_seq OWNED BY tags.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    name text NOT NULL,
    "password" text NOT NULL,
    "level" integer DEFAULT 0 NOT NULL,
	login_count integer DEFAULT 0 NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: wiki_page_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_page_versions (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr text NOT NULL,
    wiki_page_id integer NOT NULL,
    is_locked boolean DEFAULT false NOT NULL
);


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_page_versions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE wiki_page_versions_id_seq OWNED BY wiki_page_versions.id;


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_pages (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr text NOT NULL,
    is_locked boolean DEFAULT false NOT NULL
);


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_pages_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE wiki_pages_id_seq OWNED BY wiki_pages.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE favorites ALTER COLUMN id SET DEFAULT nextval('favorites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE note_versions ALTER COLUMN id SET DEFAULT nextval('note_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE notes ALTER COLUMN id SET DEFAULT nextval('notes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE post_tag_histories ALTER COLUMN id SET DEFAULT nextval('post_tag_histories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tag_aliases ALTER COLUMN id SET DEFAULT nextval('tag_aliases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tag_implications ALTER COLUMN id SET DEFAULT nextval('tag_implications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE tags ALTER COLUMN id SET DEFAULT nextval('tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE wiki_page_versions ALTER COLUMN id SET DEFAULT nextval('wiki_page_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE wiki_pages ALTER COLUMN id SET DEFAULT nextval('wiki_pages_id_seq'::regclass);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: note_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT note_versions_pkey PRIMARY KEY (id);


--
-- Name: notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: post_tag_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT post_tag_histories_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: table_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY table_data
    ADD CONSTRAINT table_data_pkey PRIMARY KEY (name);


--
-- Name: tag_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT tag_aliases_pkey PRIMARY KEY (id);


--
-- Name: tag_implications_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT tag_implications_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wiki_page_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY wiki_page_versions
    ADD CONSTRAINT wiki_page_versions_pkey PRIMARY KEY (id);


--
-- Name: wiki_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT wiki_pages_pkey PRIMARY KEY (id);


--
-- Name: idx_comments__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_comments__post ON comments USING btree (post_id);


--
-- Name: idx_favorites__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_favorites__post ON favorites USING btree (post_id);


--
-- Name: idx_favorites__post_user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_favorites__post_user ON favorites USING btree (post_id, user_id);


--
-- Name: idx_favorites__user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_favorites__user ON favorites USING btree (user_id);


--
-- Name: idx_note_versions__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_note_versions__post ON note_versions USING btree (post_id);


--
-- Name: idx_notes__note; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_notes__note ON note_versions USING btree (note_id);


--
-- Name: idx_notes__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_notes__post ON notes USING btree (post_id);


--
-- Name: idx_post_tag_histories__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_post_tag_histories__post ON post_tag_histories USING btree (post_id);


--
-- Name: idx_posts__created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__created_at ON posts USING btree (created_at);


--
-- Name: idx_posts__last_commented_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__last_commented_at ON posts USING btree (last_commented_at) WHERE last_commented_at IS NOT NULL;

--
-- Name: idx_posts__last_noted_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__last_noted_at ON posts USING btree (last_noted_at) WHERE last_noted_at IS NOT NULL;


--
-- Name: idx_posts__md5; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_posts__md5 ON posts USING btree (md5);


--
-- Name: idx_posts__user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__user ON posts USING btree (user_id) WHERE user_id IS NOT NULL;


--
-- Name: idx_posts_tags__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts_tags__post ON posts_tags USING btree (post_id);


--
-- Name: idx_posts_tags__tag; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts_tags__tag ON posts_tags USING btree (tag_id);


--
-- Name: idx_tag_aliases__name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_tag_aliases__name ON tag_aliases USING btree (name);


--
-- Name: idx_tag_implications__child; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tag_implications__child ON tag_implications USING btree (child_id);


--
-- Name: idx_tag_implications__parent; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tag_implications__parent ON tag_implications USING btree (parent_id);


--
-- Name: idx_tags__name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_tags__name ON tags USING btree (name);


--
-- Name: idx_tags__post_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tags__post_count ON tags USING btree (post_count);


--
-- Name: idx_users__name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_users__name ON users USING btree (lower(name));


--
-- Name: idx_wiki_page_versions__wiki_page; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_page_versions__wiki_page ON wiki_page_versions USING btree (wiki_page_id);


--
-- Name: idx_wiki_pages__title; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_pages__title ON wiki_pages USING btree (lower(title));


--
-- Name: idx_wiki_pages__updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_pages__updated_at ON wiki_pages USING btree (updated_at);


--
-- Name: trg_posts__insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts__insert
    BEFORE INSERT ON posts
    FOR EACH ROW
    EXECUTE PROCEDURE trg_posts__insert();


--
-- Name: trg_posts_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_delete
    BEFORE DELETE ON posts
    FOR EACH ROW
    EXECUTE PROCEDURE trg_posts__delete();


--
-- Name: trg_posts_tags__delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__delete
    BEFORE DELETE ON posts_tags
    FOR EACH ROW
    EXECUTE PROCEDURE trg_posts_tags__delete();


--
-- Name: trg_posts_tags__insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__insert
    BEFORE INSERT ON posts_tags
    FOR EACH ROW
    EXECUTE PROCEDURE trg_posts_tags__insert();


--
-- Name: trg_users_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_delete
    BEFORE DELETE ON users
    FOR EACH ROW
    EXECUTE PROCEDURE trg_users__delete();


--
-- Name: trg_users_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_insert
    BEFORE INSERT ON users
    FOR EACH ROW
    EXECUTE PROCEDURE trg_users__insert();


--
-- Name: fk_comments__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT fk_comments__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_comments__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT fk_comments__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_favorites__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT fk_favorites__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_favorites__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT fk_favorites__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: fk_note_versions__note; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT fk_note_versions__note FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE;


--
-- Name: fk_note_versions__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT fk_note_versions__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_note_versions__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY note_versions
    ADD CONSTRAINT fk_note_versions__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_notes__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notes
    ADD CONSTRAINT fk_notes__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_notes__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notes
    ADD CONSTRAINT fk_notes__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_post_tag_histories__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT fk_post_tag_histories__post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: fk_posts__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT fk_posts__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_tag_aliases__alias; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT fk_tag_aliases__alias FOREIGN KEY (alias_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_implications__child; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT fk_tag_implications__child FOREIGN KEY (child_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_implications__parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT fk_tag_implications__parent FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_wiki_page_versions__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_page_versions
    ADD CONSTRAINT fk_wiki_page_versions__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: fk_wiki_page_versions__wiki_page; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_page_versions
    ADD CONSTRAINT fk_wiki_page_versions__wiki_page FOREIGN KEY (wiki_page_id) REFERENCES wiki_pages(id) ON DELETE CASCADE;


--
-- Name: fk_wiki_pages__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_pages
    ADD CONSTRAINT fk_wiki_pages__user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


INSERT INTO table_data (name, row_count) VALUES ('posts', 0), ('users', 0);

--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

