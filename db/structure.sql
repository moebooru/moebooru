--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: test_parser; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS test_parser WITH SCHEMA public;


--
-- Name: EXTENSION test_parser; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION test_parser IS 'example of a custom parser for full-text search';


SET search_path = public, pg_catalog;

--
-- Name: post_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE post_status AS ENUM (
    'deleted',
    'flagged',
    'pending',
    'active'
);


--
-- Name: get_new_tags(character varying[], character varying[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_new_tags(old_array character varying[], new_array character varying[]) RETURNS character varying[]
    LANGUAGE plpgsql
    AS $$
    DECLARE
      changed_tags varchar[];
    BEGIN
      FOR i IN array_lower(new_array, 1) .. array_upper(new_array, 1) LOOP
        IF NOT new_array[i] = ANY (old_array) THEN
          changed_tags := array_append(changed_tags, new_array[i]);
        END IF;
      END LOOP;

      RETURN changed_tags;
    END
    $$;


--
-- Name: history_changes_index_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION history_changes_index_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
      old_tags varchar;
      old_tags_array varchar[];
      new_tags_array varchar[];
      changed_tags_array varchar[];
      indexed_value varchar;
    BEGIN
      IF (new.table_name, new.column_name) IN (('posts', 'cached_tags')) THEN
        old_tags := prev.value FROM history_changes prev WHERE (prev.id = new.previous_id) LIMIT 1;
        old_tags_array := regexp_split_to_array(COALESCE(old_tags, ''), ' ');
        new_tags_array := regexp_split_to_array(COALESCE(new.value, ''), ' ');

        changed_tags_array := get_new_tags(old_tags_array, new_tags_array);
        changed_tags_array := array_cat(changed_tags_array, get_new_tags(new_tags_array, old_tags_array));
        indexed_value := join_string(changed_tags_array, ' ');
      ELSEIF (new.table_name, new.column_name) IN (('pools', 'name')) THEN
        indexed_value := translate(new.value, '_', ' ');
      ELSEIF (new.table_name, new.column_name) IN (('posts', 'cached_tags'), ('posts', 'source'), ('pools', 'description'), ('notes', 'body')) THEN
        indexed_value := new.value;
      ELSE
        RETURN new;
      END IF;

      new.value_index := to_tsvector('public.danbooru', indexed_value);

      RETURN new;
    END
    $$;


--
-- Name: join_string(character varying[], character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION join_string(words character varying[], delimitor character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
    DECLARE
      result varchar := '';
      first boolean := true;
    BEGIN
      FOR i IN coalesce(array_lower(words, 1), 0) .. coalesce(array_upper(words, 1), 0) LOOP
        IF NOT first THEN
          result := result || delimitor;
        ELSE
          first := false;
        END IF;
        
        result := result || words[i];
      END LOOP;
      RETURN result;
    END
    $$;


--
-- Name: nat_sort(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION nat_sort(t text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      BEGIN
        return array_to_string(array(select nat_sort_pad((regexp_matches(t, '([0-9]+|[^0-9]+)', 'g'))[1])), '');
      END;
      $$;


--
-- Name: nat_sort_pad(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION nat_sort_pad(t text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
      DECLARE
        match text;
      BEGIN
        IF t ~ '[0-9]' THEN
          match := '0000000000' || t;
          match := SUBSTRING(match FROM '^0*([0-9]{10}[0-9]*)$');
          return match;
        END IF;
        return t;
      END;
      $_$;


--
-- Name: pools_posts_delete_trg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pools_posts_delete_trg() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF (OLD.active) THEN
          UPDATE pools SET post_count = post_count - 1 WHERE id = OLD.pool_id;
        END IF;
        RETURN OLD;
      END;
      $$;


--
-- Name: pools_posts_insert_trg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pools_posts_insert_trg() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF (NEW.active) THEN
          UPDATE pools SET post_count = post_count + 1 WHERE id = NEW.pool_id;
        END IF;
        RETURN NEW;
      END;
      $$;


--
-- Name: pools_posts_update_trg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pools_posts_update_trg() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF (OLD.active <> NEW.active) THEN
          IF (NEW.active) THEN
            UPDATE pools SET post_count = post_count + 1 WHERE id = NEW.pool_id;
          ELSE
            UPDATE pools SET post_count = post_count - 1 WHERE id = NEW.pool_id;
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;


--
-- Name: pools_search_update_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION pools_search_update_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        new.search_index := to_tsvector('pg_catalog.english', replace_underscores(new.name) || ' ' || new.description);
        RETURN new;
      END
      $$;


--
-- Name: replace_underscores(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION replace_underscores(s character varying) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
    AS $$
        BEGIN
          RETURN regexp_replace(s, '_', ' ', 'g');
        END;
      $$;


--
-- Name: trg_posts_tags__delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts_tags__delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        UPDATE tags SET post_count = post_count - 1 WHERE tags.id = OLD.tag_id;
        RETURN OLD;
      END;
      $$;


--
-- Name: trg_posts_tags__insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_posts_tags__insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        UPDATE tags SET post_count = post_count + 1 WHERE tags.id = NEW.tag_id;
        RETURN NEW;
      END;
      $$;


--
-- Name: trg_purge_histories(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION trg_purge_histories() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        DELETE FROM histories h WHERE h.id = OLD.history_id AND
          (SELECT COUNT(*) FROM history_changes hc WHERE hc.history_id = OLD.history_id LIMIT 1) = 0;
        RETURN OLD;
      END;
      $$;


--
-- Name: user_logs_touch(integer, inet); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION user_logs_touch(new_user_id integer, new_ip inet) RETURNS void
    LANGUAGE plpgsql
    AS $$
      BEGIN
	FOR i IN 1..3 LOOP
	  UPDATE user_logs SET created_at = now() where user_id = new_user_id and ip_addr = new_ip;
	  IF found THEN
	    RETURN;
	  END IF;

	  BEGIN
	    INSERT INTO user_logs (user_id, ip_addr) VALUES (new_user_id, new_ip);
	    RETURN;
	  EXCEPTION WHEN unique_violation THEN
	    -- Try again.
	  END;
	END LOOP;
      END;
      $$;


--
-- Name: danbooru; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION danbooru (
    PARSER = testparser );

ALTER TEXT SEARCH CONFIGURATION danbooru
    ADD MAPPING FOR word WITH simple;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: advertisements; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE advertisements (
    id integer NOT NULL,
    image_url character varying(255) NOT NULL,
    referral_url character varying(255) NOT NULL,
    ad_type character varying(255) NOT NULL,
    status character varying(255) NOT NULL,
    hit_count integer DEFAULT 0 NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL
);


--
-- Name: advertisements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE advertisements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: advertisements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE advertisements_id_seq OWNED BY advertisements.id;


--
-- Name: artist_urls; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE artist_urls (
    id integer NOT NULL,
    artist_id integer NOT NULL,
    url text NOT NULL,
    normalized_url text NOT NULL
);


--
-- Name: artist_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE artist_urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artist_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE artist_urls_id_seq OWNED BY artist_urls.id;


--
-- Name: artists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE artists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artists; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE artists (
    id integer DEFAULT nextval('artists_id_seq'::regclass) NOT NULL,
    alias_id integer,
    group_id integer,
    name text NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updater_id integer
);


--
-- Name: bans; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bans (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reason text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    banned_by integer NOT NULL,
    old_level integer
);


--
-- Name: bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bans_id_seq OWNED BY bans.id;


--
-- Name: batch_uploads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE batch_uploads (
    id integer NOT NULL,
    user_id integer NOT NULL,
    ip inet,
    url text NOT NULL,
    tags character varying(255) DEFAULT ''::character varying NOT NULL,
    active boolean DEFAULT false NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT '2010-08-31 04:17:31.209032'::timestamp without time zone NOT NULL,
    data_as_json character varying(255) DEFAULT '{}'::character varying NOT NULL
);


--
-- Name: batch_uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE batch_uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: batch_uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE batch_uploads_id_seq OWNED BY batch_uploads.id;


--
-- Name: comment_fragments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comment_fragments (
    id integer NOT NULL,
    comment_id integer NOT NULL,
    block_id integer NOT NULL,
    source_lang text NOT NULL,
    target_lang text NOT NULL,
    body text NOT NULL
);


--
-- Name: comment_fragments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comment_fragments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_fragments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comment_fragments_id_seq OWNED BY comment_fragments.id;


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comments (
    id integer DEFAULT nextval('comments_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    post_id integer NOT NULL,
    user_id integer,
    body text NOT NULL,
    ip_addr inet NOT NULL,
    is_spam boolean,
    text_search_index tsvector,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: dmails; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE dmails (
    id integer NOT NULL,
    from_id integer NOT NULL,
    to_id integer NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    has_seen boolean DEFAULT false NOT NULL,
    parent_id integer
);


--
-- Name: dmails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE dmails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dmails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE dmails_id_seq OWNED BY dmails.id;


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE favorites (
    id integer DEFAULT nextval('favorites_id_seq'::regclass) NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: flagged_post_details; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE flagged_post_details (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    post_id integer NOT NULL,
    reason text NOT NULL,
    user_id integer,
    is_resolved boolean NOT NULL
);


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE flagged_post_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE flagged_post_details_id_seq OWNED BY flagged_post_details.id;


--
-- Name: forum_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE forum_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE forum_posts (
    id integer DEFAULT nextval('forum_posts_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    creator_id integer NOT NULL,
    parent_id integer,
    last_updated_by integer,
    is_sticky boolean DEFAULT false NOT NULL,
    response_count integer DEFAULT 0 NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: forum_posts_user_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE forum_posts_user_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: histories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE histories (
    id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    user_id integer,
    group_by_id integer NOT NULL,
    group_by_table text NOT NULL,
    aux_as_json text
);


--
-- Name: histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE histories_id_seq OWNED BY histories.id;


--
-- Name: history_changes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE history_changes (
    id integer NOT NULL,
    column_name text NOT NULL,
    remote_id integer NOT NULL,
    table_name text NOT NULL,
    value text,
    history_id integer NOT NULL,
    previous_id integer,
    value_index tsvector
);


--
-- Name: history_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE history_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: history_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE history_changes_id_seq OWNED BY history_changes.id;


--
-- Name: inline_images; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE inline_images (
    id integer NOT NULL,
    inline_id integer NOT NULL,
    md5 text NOT NULL,
    file_ext text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    sequence integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    sample_width integer,
    sample_height integer
);


--
-- Name: inline_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE inline_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inline_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE inline_images_id_seq OWNED BY inline_images.id;


--
-- Name: inlines; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE inlines (
    id integer NOT NULL,
    user_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    description text DEFAULT ''::text NOT NULL
);


--
-- Name: inlines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE inlines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inlines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE inlines_id_seq OWNED BY inlines.id;


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_bans; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE ip_bans (
    id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    expires_at timestamp without time zone,
    ip_addr inet NOT NULL,
    reason text NOT NULL,
    banned_by integer NOT NULL
);


--
-- Name: ip_bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE ip_bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE ip_bans_id_seq OWNED BY ip_bans.id;


--
-- Name: job_tasks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE job_tasks (
    id integer NOT NULL,
    task_type character varying(255) NOT NULL,
    status character varying(255) NOT NULL,
    status_message text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    data_as_json text DEFAULT '{}'::text NOT NULL,
    repeat_count integer DEFAULT 0 NOT NULL
);


--
-- Name: job_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE job_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE job_tasks_id_seq OWNED BY job_tasks.id;


--
-- Name: news_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE news_updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE note_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE note_versions (
    id integer DEFAULT nextval('note_versions_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    body text NOT NULL,
    version integer NOT NULL,
    ip_addr inet NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    note_id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer,
    text_search_index tsvector
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notes (
    id integer DEFAULT nextval('notes_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    ip_addr inet NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    post_id integer NOT NULL,
    body text NOT NULL,
    text_search_index tsvector
);


--
-- Name: pools; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pools (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    is_public boolean DEFAULT true NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    zip_created_at timestamp without time zone,
    zip_is_warehoused boolean DEFAULT false NOT NULL,
    search_index tsvector
);


--
-- Name: pools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pools_id_seq OWNED BY pools.id;


--
-- Name: pools_posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pools_posts (
    id integer NOT NULL,
    sequence text DEFAULT 0 NOT NULL,
    pool_id integer NOT NULL,
    post_id integer NOT NULL,
    next_post_id integer,
    prev_post_id integer,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: pools_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pools_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pools_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pools_posts_id_seq OWNED BY pools_posts.id;


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts (
    id integer DEFAULT nextval('posts_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    user_id integer,
    source text DEFAULT ''::text NOT NULL,
    md5 text NOT NULL,
    last_commented_at timestamp without time zone,
    rating character(1) DEFAULT 'q'::bpchar NOT NULL,
    width integer,
    height integer,
    is_warehoused boolean DEFAULT false NOT NULL,
    ip_addr inet NOT NULL,
    cached_tags text DEFAULT ''::text NOT NULL,
    is_note_locked boolean DEFAULT false NOT NULL,
    file_ext text DEFAULT ''::text NOT NULL,
    last_noted_at timestamp without time zone,
    is_rating_locked boolean DEFAULT false NOT NULL,
    parent_id integer,
    has_children boolean DEFAULT false NOT NULL,
    status post_status DEFAULT 'active'::post_status NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    sample_width integer,
    sample_height integer,
    sample_quality integer,
    change_seq integer,
    random real DEFAULT random() NOT NULL,
    approver_id integer,
    score integer DEFAULT 0 NOT NULL,
    file_size integer DEFAULT 0 NOT NULL,
    sample_size integer DEFAULT 0 NOT NULL,
    crc32 bigint,
    sample_crc32 bigint,
    is_held boolean DEFAULT false NOT NULL,
    index_timestamp timestamp without time zone DEFAULT now() NOT NULL,
    is_shown_in_index boolean DEFAULT true NOT NULL,
    jpeg_width integer,
    jpeg_height integer,
    jpeg_size integer DEFAULT 0 NOT NULL,
    jpeg_crc32 bigint,
    tags_index tsvector,
    frames text DEFAULT ''::text NOT NULL,
    frames_pending text DEFAULT ''::text NOT NULL,
    frames_warehoused boolean DEFAULT false NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: post_change_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_change_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_change_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_change_seq OWNED BY posts.change_seq;


--
-- Name: post_frames; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_frames (
    id integer NOT NULL,
    post_id integer NOT NULL,
    is_target boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    is_created boolean DEFAULT false NOT NULL,
    is_warehoused boolean DEFAULT false NOT NULL,
    source_width integer NOT NULL,
    source_height integer NOT NULL,
    source_top integer NOT NULL,
    source_left integer NOT NULL
);


--
-- Name: post_frames_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_frames_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_frames_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_frames_id_seq OWNED BY post_frames.id;


--
-- Name: post_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_tag_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tag_histories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_tag_histories (
    id integer DEFAULT nextval('post_tag_histories_id_seq'::regclass) NOT NULL,
    post_id integer NOT NULL,
    tags text NOT NULL,
    user_id integer,
    ip_addr inet,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: post_votes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_votes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    score integer DEFAULT 0 NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_votes_id_seq OWNED BY post_votes.id;


--
-- Name: posts_id_seq2; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE posts_id_seq2
    START WITH 7168
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts_tags (
    post_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: table_data; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE table_data (
    name text NOT NULL,
    row_count integer NOT NULL
);


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_aliases; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_aliases (
    id integer DEFAULT nextval('tag_aliases_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    alias_id integer NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    creator_id integer
);


--
-- Name: tag_implications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_implications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_implications; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_implications (
    id integer DEFAULT nextval('tag_implications_id_seq'::regclass) NOT NULL,
    consequent_id integer NOT NULL,
    predicate_id integer NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    creator_id integer
);


--
-- Name: tag_subscriptions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tag_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tag_query text NOT NULL,
    cached_post_ids text DEFAULT ''::text NOT NULL,
    name character varying(255) DEFAULT 'General'::character varying NOT NULL,
    is_visible_on_profile boolean DEFAULT true NOT NULL
);


--
-- Name: tag_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tag_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tag_subscriptions_id_seq OWNED BY tag_subscriptions.id;


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tags (
    id integer DEFAULT nextval('tags_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    cached_related text DEFAULT '[]'::text NOT NULL,
    cached_related_expires_on timestamp without time zone DEFAULT now() NOT NULL,
    tag_type smallint DEFAULT 0 NOT NULL,
    is_ambiguous boolean DEFAULT false NOT NULL,
    safe_post_count integer DEFAULT 0 NOT NULL
);


--
-- Name: user_blacklisted_tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_blacklisted_tags (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tags text NOT NULL
);


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_blacklisted_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_blacklisted_tags_id_seq OWNED BY user_blacklisted_tags.id;


--
-- Name: user_logs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_logs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    ip_addr inet NOT NULL
);


--
-- Name: user_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_logs_id_seq OWNED BY user_logs.id;


--
-- Name: user_records; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_records (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reported_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    is_positive boolean DEFAULT true NOT NULL,
    body text NOT NULL
);


--
-- Name: user_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_records_id_seq OWNED BY user_records.id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer DEFAULT nextval('users_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    password_hash text NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    email text DEFAULT ''::text NOT NULL,
    my_tags text DEFAULT ''::text NOT NULL,
    invite_count integer DEFAULT 0 NOT NULL,
    always_resize_images boolean DEFAULT false NOT NULL,
    invited_by integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    last_logged_in_at timestamp without time zone DEFAULT now() NOT NULL,
    last_forum_topic_read_at timestamp without time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
    has_mail boolean DEFAULT false NOT NULL,
    receive_dmails boolean DEFAULT false NOT NULL,
    show_samples boolean DEFAULT true,
    avatar_post_id integer,
    avatar_width real,
    avatar_height real,
    avatar_top real,
    avatar_bottom real,
    avatar_left real,
    avatar_right real,
    avatar_timestamp timestamp without time zone,
    last_comment_read_at timestamp without time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
    last_deleted_post_seen_at timestamp without time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
    show_advanced_editing boolean DEFAULT false NOT NULL,
    language text DEFAULT ''::text NOT NULL,
    secondary_languages text DEFAULT ''::text NOT NULL,
    pool_browse_mode integer DEFAULT 1 NOT NULL,
    use_browser boolean DEFAULT false NOT NULL,
    api_key character varying(255)
);


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_page_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_page_versions (
    id integer DEFAULT nextval('wiki_page_versions_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr inet NOT NULL,
    wiki_page_id integer NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_pages (
    id integer DEFAULT nextval('wiki_pages_id_seq'::regclass) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr inet NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY advertisements ALTER COLUMN id SET DEFAULT nextval('advertisements_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY artist_urls ALTER COLUMN id SET DEFAULT nextval('artist_urls_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bans ALTER COLUMN id SET DEFAULT nextval('bans_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY batch_uploads ALTER COLUMN id SET DEFAULT nextval('batch_uploads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY comment_fragments ALTER COLUMN id SET DEFAULT nextval('comment_fragments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails ALTER COLUMN id SET DEFAULT nextval('dmails_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY flagged_post_details ALTER COLUMN id SET DEFAULT nextval('flagged_post_details_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY histories ALTER COLUMN id SET DEFAULT nextval('histories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY history_changes ALTER COLUMN id SET DEFAULT nextval('history_changes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY inline_images ALTER COLUMN id SET DEFAULT nextval('inline_images_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY inlines ALTER COLUMN id SET DEFAULT nextval('inlines_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY ip_bans ALTER COLUMN id SET DEFAULT nextval('ip_bans_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY job_tasks ALTER COLUMN id SET DEFAULT nextval('job_tasks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools ALTER COLUMN id SET DEFAULT nextval('pools_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts ALTER COLUMN id SET DEFAULT nextval('pools_posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_frames ALTER COLUMN id SET DEFAULT nextval('post_frames_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_votes ALTER COLUMN id SET DEFAULT nextval('post_votes_id_seq'::regclass);


--
-- Name: change_seq; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts ALTER COLUMN change_seq SET DEFAULT nextval('post_change_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_subscriptions ALTER COLUMN id SET DEFAULT nextval('tag_subscriptions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_blacklisted_tags ALTER COLUMN id SET DEFAULT nextval('user_blacklisted_tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_logs ALTER COLUMN id SET DEFAULT nextval('user_logs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_records ALTER COLUMN id SET DEFAULT nextval('user_records_id_seq'::regclass);


--
-- Name: advertisements_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY advertisements
    ADD CONSTRAINT advertisements_pkey PRIMARY KEY (id);


--
-- Name: artist_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artist_urls
    ADD CONSTRAINT artist_urls_pkey PRIMARY KEY (id);


--
-- Name: artists_name_uniq; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_name_uniq UNIQUE (name);


--
-- Name: artists_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_pkey PRIMARY KEY (id);


--
-- Name: bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bans
    ADD CONSTRAINT bans_pkey PRIMARY KEY (id);


--
-- Name: batch_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY batch_uploads
    ADD CONSTRAINT batch_uploads_pkey PRIMARY KEY (id);


--
-- Name: batch_uploads_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY batch_uploads
    ADD CONSTRAINT batch_uploads_user_id_key UNIQUE (user_id, url);


--
-- Name: comment_fragments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comment_fragments
    ADD CONSTRAINT comment_fragments_pkey PRIMARY KEY (id);


--
-- Name: comment_fragments_unique; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comment_fragments
    ADD CONSTRAINT comment_fragments_unique UNIQUE (comment_id, block_id, source_lang, target_lang);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: dmails_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_pkey PRIMARY KEY (id);


--
-- Name: favorite_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tag_subscriptions
    ADD CONSTRAINT favorite_tags_pkey PRIMARY KEY (id);


--
-- Name: favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: flagged_post_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY flagged_post_details
    ADD CONSTRAINT flagged_post_details_pkey PRIMARY KEY (id);


--
-- Name: forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);


--
-- Name: histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY histories
    ADD CONSTRAINT histories_pkey PRIMARY KEY (id);


--
-- Name: history_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY history_changes
    ADD CONSTRAINT history_changes_pkey PRIMARY KEY (id);


--
-- Name: inline_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY inline_images
    ADD CONSTRAINT inline_images_pkey PRIMARY KEY (id);


--
-- Name: inlines_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY inlines
    ADD CONSTRAINT inlines_pkey PRIMARY KEY (id);


--
-- Name: ip_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY ip_bans
    ADD CONSTRAINT ip_bans_pkey PRIMARY KEY (id);


--
-- Name: job_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY job_tasks
    ADD CONSTRAINT job_tasks_pkey PRIMARY KEY (id);


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
-- Name: pools_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pools
    ADD CONSTRAINT pools_pkey PRIMARY KEY (id);


--
-- Name: pools_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_pkey PRIMARY KEY (id);


--
-- Name: post_frames_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_frames
    ADD CONSTRAINT post_frames_pkey PRIMARY KEY (id);


--
-- Name: post_tag_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT post_tag_histories_pkey PRIMARY KEY (id);


--
-- Name: post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_pkey PRIMARY KEY (id);


--
-- Name: post_votes_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_user_id_key UNIQUE (user_id, post_id);


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

ALTER TABLE tags CLUSTER ON tags_pkey;


--
-- Name: user_blacklisted_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_blacklisted_tags
    ADD CONSTRAINT user_blacklisted_tags_pkey PRIMARY KEY (id);


--
-- Name: user_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_logs
    ADD CONSTRAINT user_logs_pkey PRIMARY KEY (id);


--
-- Name: user_logs_user_ip; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_logs
    ADD CONSTRAINT user_logs_user_ip UNIQUE (user_id, ip_addr);


--
-- Name: user_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_records
    ADD CONSTRAINT user_records_pkey PRIMARY KEY (id);


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
-- Name: comments_text_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX comments_text_search_idx ON comments USING gin (text_search_index);


--
-- Name: forum_posts__parent_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX forum_posts__parent_id_idx ON forum_posts USING btree (parent_id) WHERE (parent_id IS NULL);


--
-- Name: forum_posts_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX forum_posts_search_idx ON forum_posts USING gin (text_search_index);


--
-- Name: idx_comments__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_comments__post ON comments USING btree (post_id);


--
-- Name: idx_favorites__post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_favorites__post ON favorites USING btree (post_id);


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
-- Name: idx_pools__name_nat; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_pools__name_nat ON pools USING btree (nat_sort(name));


--
-- Name: idx_pools_posts__sequence_nat; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_pools_posts__sequence_nat ON pools_posts USING btree (nat_sort(sequence));


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

CREATE INDEX idx_posts__last_commented_at ON posts USING btree (last_commented_at) WHERE (last_commented_at IS NOT NULL);


--
-- Name: idx_posts__last_noted_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__last_noted_at ON posts USING btree (last_noted_at) WHERE (last_noted_at IS NOT NULL);


--
-- Name: idx_posts__md5; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_posts__md5 ON posts USING btree (md5);


--
-- Name: idx_posts__user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts__user ON posts USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_posts_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_posts_parent_id ON posts USING btree (parent_id) WHERE (parent_id IS NOT NULL);


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

CREATE INDEX idx_tag_implications__child ON tag_implications USING btree (predicate_id);


--
-- Name: idx_tag_implications__parent; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_tag_implications__parent ON tag_implications USING btree (consequent_id);


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

CREATE UNIQUE INDEX idx_users__name ON users USING btree (lower(name));


--
-- Name: idx_wiki_page_versions__wiki_page; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_page_versions__wiki_page ON wiki_page_versions USING btree (wiki_page_id);


--
-- Name: idx_wiki_pages__title; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_wiki_pages__title ON wiki_pages USING btree (title);


--
-- Name: idx_wiki_pages__updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_wiki_pages__updated_at ON wiki_pages USING btree (updated_at);


--
-- Name: index_artist_urls_on_artist_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_urls_on_artist_id ON artist_urls USING btree (artist_id);


--
-- Name: index_artist_urls_on_normalized_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_urls_on_normalized_url ON artist_urls USING btree (normalized_url);


--
-- Name: index_artist_urls_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_artist_urls_on_url ON artist_urls USING btree (url);


--
-- Name: index_bans_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bans_on_user_id ON bans USING btree (user_id);


--
-- Name: index_comment_fragments_on_comment_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comment_fragments_on_comment_id ON comment_fragments USING btree (comment_id);


--
-- Name: index_dmails_on_from_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_dmails_on_from_id ON dmails USING btree (from_id);


--
-- Name: index_dmails_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_dmails_on_parent_id ON dmails USING btree (parent_id);


--
-- Name: index_dmails_on_to_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_dmails_on_to_id ON dmails USING btree (to_id);


--
-- Name: index_flagged_post_details_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_flagged_post_details_on_created_at ON flagged_post_details USING btree (created_at);


--
-- Name: index_flagged_post_details_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_flagged_post_details_on_post_id ON flagged_post_details USING btree (post_id);


--
-- Name: index_forum_posts_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_posts_on_updated_at ON forum_posts USING btree (updated_at);


--
-- Name: index_histories_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_histories_on_created_at ON histories USING btree (created_at);


--
-- Name: index_histories_on_group_by_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_histories_on_group_by_id ON histories USING btree (group_by_id);


--
-- Name: index_histories_on_group_by_table; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_histories_on_group_by_table ON histories USING btree (group_by_table);


--
-- Name: index_histories_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_histories_on_user_id ON histories USING btree (user_id);


--
-- Name: index_history_changes_on_history_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_history_changes_on_history_id ON history_changes USING btree (history_id);


--
-- Name: index_history_changes_on_previous_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_history_changes_on_previous_id ON history_changes USING btree (previous_id);


--
-- Name: index_history_changes_on_remote_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_history_changes_on_remote_id ON history_changes USING btree (remote_id);


--
-- Name: index_history_changes_on_table_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_history_changes_on_table_name ON history_changes USING btree (table_name);


--
-- Name: index_history_changes_on_value_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_history_changes_on_value_index ON history_changes USING gin (value_index);


--
-- Name: index_inline_images_on_inline_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_inline_images_on_inline_id ON inline_images USING btree (inline_id);


--
-- Name: index_ip_bans_on_ip_addr; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_ip_bans_on_ip_addr ON ip_bans USING btree (ip_addr);


--
-- Name: index_note_versions_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_note_versions_on_user_id ON note_versions USING btree (user_id);


--
-- Name: index_pools_posts_on_active; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_pools_posts_on_active ON pools_posts USING btree (active);


--
-- Name: index_post_frames_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_frames_on_post_id ON post_frames USING btree (post_id);


--
-- Name: index_post_tag_histories_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_tag_histories_on_user_id ON post_tag_histories USING btree (user_id);


--
-- Name: index_post_votes_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_votes_on_post_id ON post_votes USING btree (post_id);


--
-- Name: index_post_votes_on_updated_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_votes_on_updated_at ON post_votes USING btree (updated_at);


--
-- Name: index_post_votes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_votes_on_user_id ON post_votes USING btree (user_id);


--
-- Name: index_posts_on_change_seq; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_change_seq ON posts USING btree (change_seq);


--
-- Name: index_posts_on_height; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_height ON posts USING btree (height);


--
-- Name: index_posts_on_index_timestamp; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_index_timestamp ON posts USING btree (index_timestamp);


--
-- Name: index_posts_on_is_held; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_is_held ON posts USING btree (is_held);


--
-- Name: index_posts_on_random; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_random ON posts USING btree (random);


--
-- Name: index_posts_on_source; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_source ON posts USING btree (source);


--
-- Name: index_posts_on_tags_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_tags_index ON posts USING gin (tags_index);


--
-- Name: index_posts_on_width; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_width ON posts USING btree (width);


--
-- Name: index_posts_tags_on_post_id_and_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_posts_tags_on_post_id_and_tag_id ON posts_tags USING btree (post_id, tag_id);


--
-- Name: index_tag_subscriptions_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tag_subscriptions_on_name ON tag_subscriptions USING btree (name);


--
-- Name: index_tag_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_tag_subscriptions_on_user_id ON tag_subscriptions USING btree (user_id);


--
-- Name: index_user_blacklisted_tags_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_blacklisted_tags_on_user_id ON user_blacklisted_tags USING btree (user_id);


--
-- Name: index_user_logs_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_logs_on_user_id ON user_logs USING btree (user_id);


--
-- Name: index_users_on_api_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_api_key ON users USING btree (api_key);


--
-- Name: index_users_on_avatar_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_avatar_post_id ON users USING btree (avatar_post_id);


--
-- Name: notes_text_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX notes_text_search_idx ON notes USING gin (text_search_index);


--
-- Name: pools_posts_pool_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pools_posts_pool_id_idx ON pools_posts USING btree (pool_id);


--
-- Name: pools_posts_post_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pools_posts_post_id_idx ON pools_posts USING btree (post_id);


--
-- Name: pools_user_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX pools_user_id_idx ON pools USING btree (user_id);


--
-- Name: post_frames_out_of_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX post_frames_out_of_date ON posts USING btree (id) WHERE ((frames <> frames_pending) AND ((frames <> ''::text) OR (frames_pending <> ''::text)));


--
-- Name: post_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX post_search_idx ON pools USING gin (search_index);


--
-- Name: post_status_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX post_status_idx ON posts USING btree (status) WHERE (status < 'active'::post_status);


--
-- Name: posts_mpixels; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX posts_mpixels ON posts USING btree (((((width * height))::numeric / 1000000.0)));


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: user_logs_created_at_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX user_logs_created_at_idx ON user_logs USING btree (created_at);


--
-- Name: user_logs_user_id_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX user_logs_user_id_idx ON user_logs USING btree (user_id);


--
-- Name: wiki_pages_search_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX wiki_pages_search_idx ON wiki_pages USING gin (text_search_index);


--
-- Name: delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO pools DO ( DELETE FROM history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'pools'::text));
 DELETE FROM histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'pools'::text));
);


--
-- Name: delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO pools_posts DO ( DELETE FROM history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'pools_posts'::text));
 DELETE FROM histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'pools_posts'::text));
);


--
-- Name: delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO posts DO ( DELETE FROM history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'posts'::text));
 DELETE FROM histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'posts'::text));
);


--
-- Name: delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO tags DO ( DELETE FROM history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'tags'::text));
 DELETE FROM histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'tags'::text));
);


--
-- Name: pools_posts_delete_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_delete_trg BEFORE DELETE ON pools_posts FOR EACH ROW EXECUTE PROCEDURE pools_posts_delete_trg();


--
-- Name: pools_posts_insert_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_insert_trg BEFORE INSERT ON pools_posts FOR EACH ROW EXECUTE PROCEDURE pools_posts_insert_trg();


--
-- Name: pools_posts_update_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_update_trg BEFORE UPDATE ON pools_posts FOR EACH ROW EXECUTE PROCEDURE pools_posts_update_trg();


--
-- Name: trg_cleanup_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cleanup_history AFTER DELETE ON history_changes FOR EACH ROW EXECUTE PROCEDURE trg_purge_histories();


--
-- Name: trg_comment_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_comment_search_update BEFORE INSERT OR UPDATE ON comments FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'body');


--
-- Name: trg_forum_post_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_forum_post_search_update BEFORE INSERT OR UPDATE ON forum_posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'title', 'body');


--
-- Name: trg_history_changes_value_index_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_history_changes_value_index_update BEFORE INSERT OR UPDATE ON history_changes FOR EACH ROW EXECUTE PROCEDURE history_changes_index_trigger();


--
-- Name: trg_note_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_note_search_update BEFORE INSERT OR UPDATE ON notes FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'body');


--
-- Name: trg_pools_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pools_search_update BEFORE INSERT OR UPDATE ON pools FOR EACH ROW EXECUTE PROCEDURE pools_search_update_trigger();


--
-- Name: trg_posts_tags__delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__delete BEFORE DELETE ON posts_tags FOR EACH ROW EXECUTE PROCEDURE trg_posts_tags__delete();


--
-- Name: trg_posts_tags__insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__insert BEFORE INSERT ON posts_tags FOR EACH ROW EXECUTE PROCEDURE trg_posts_tags__insert();


--
-- Name: trg_posts_tags_index_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags_index_update BEFORE INSERT OR UPDATE ON posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('tags_index', 'public.danbooru', 'cached_tags');


--
-- Name: trg_wiki_page_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_wiki_page_search_update BEFORE INSERT OR UPDATE ON wiki_pages FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'title', 'body');


--
-- Name: artist_urls_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artist_urls
    ADD CONSTRAINT artist_urls_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES artists(id);


--
-- Name: artists_alias_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_alias_id_fkey FOREIGN KEY (alias_id) REFERENCES artists(id) ON DELETE SET NULL;


--
-- Name: artists_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_group_id_fkey FOREIGN KEY (group_id) REFERENCES artists(id) ON DELETE SET NULL;


--
-- Name: artists_updater_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY artists
    ADD CONSTRAINT artists_updater_id_fkey FOREIGN KEY (updater_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: bans_banned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bans
    ADD CONSTRAINT bans_banned_by_fkey FOREIGN KEY (banned_by) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: bans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY bans
    ADD CONSTRAINT bans_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: batch_uploads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY batch_uploads
    ADD CONSTRAINT batch_uploads_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: comment_fragments_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY comment_fragments
    ADD CONSTRAINT comment_fragments_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE;


--
-- Name: dmails_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_from_id_fkey FOREIGN KEY (from_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: dmails_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES dmails(id);


--
-- Name: dmails_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY dmails
    ADD CONSTRAINT dmails_to_id_fkey FOREIGN KEY (to_id) REFERENCES users(id) ON DELETE CASCADE;


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
-- Name: fk_favorites__post ; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY favorites
    ADD CONSTRAINT "fk_favorites__post " FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


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
-- Name: fk_posts_tags__tag; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts_tags
    ADD CONSTRAINT fk_posts_tags__tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_aliases__alias; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT fk_tag_aliases__alias FOREIGN KEY (alias_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_implications__child; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT fk_tag_implications__child FOREIGN KEY (predicate_id) REFERENCES tags(id) ON DELETE CASCADE;


--
-- Name: fk_tag_implications__parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT fk_tag_implications__parent FOREIGN KEY (consequent_id) REFERENCES tags(id) ON DELETE CASCADE;


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


--
-- Name: flagged_post_details_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY flagged_post_details
    ADD CONSTRAINT flagged_post_details_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: flagged_post_details_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY flagged_post_details
    ADD CONSTRAINT flagged_post_details_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: forum_posts_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: forum_posts_last_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: forum_posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY forum_posts
    ADD CONSTRAINT forum_posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES forum_posts(id) ON DELETE CASCADE;


--
-- Name: history_changes_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY history_changes
    ADD CONSTRAINT history_changes_history_id_fkey FOREIGN KEY (history_id) REFERENCES histories(id) ON DELETE CASCADE;


--
-- Name: history_changes_previous_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY history_changes
    ADD CONSTRAINT history_changes_previous_id_fkey FOREIGN KEY (previous_id) REFERENCES history_changes(id) ON DELETE SET NULL;


--
-- Name: inline_images_inline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY inline_images
    ADD CONSTRAINT inline_images_inline_id_fkey FOREIGN KEY (inline_id) REFERENCES inlines(id) ON DELETE CASCADE;


--
-- Name: inlines_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY inlines
    ADD CONSTRAINT inlines_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: pools_posts_next_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_next_post_id_fkey FOREIGN KEY (next_post_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- Name: pools_posts_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES pools(id) ON DELETE CASCADE;


--
-- Name: pools_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: pools_posts_prev_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools_posts
    ADD CONSTRAINT pools_posts_prev_post_id_fkey FOREIGN KEY (prev_post_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- Name: pools_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY pools
    ADD CONSTRAINT pools_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: post_frames_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_frames
    ADD CONSTRAINT post_frames_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: post_tag_histories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_tag_histories
    ADD CONSTRAINT post_tag_histories_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: post_votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;


--
-- Name: post_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_votes
    ADD CONSTRAINT post_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: posts_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES users(id) ON DELETE SET NULL;


--
-- Name: posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- Name: tag_aliases_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_aliases
    ADD CONSTRAINT tag_aliases_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: tag_implications_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_implications
    ADD CONSTRAINT tag_implications_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: tag_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY tag_subscriptions
    ADD CONSTRAINT tag_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_blacklisted_tags_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_blacklisted_tags
    ADD CONSTRAINT user_blacklisted_tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_logs
    ADD CONSTRAINT user_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_records_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_records
    ADD CONSTRAINT user_records_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: user_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_records
    ADD CONSTRAINT user_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;


--
-- Name: users_avatar_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_avatar_post_id_fkey FOREIGN KEY (avatar_post_id) REFERENCES posts(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('1');

INSERT INTO schema_migrations (version) VALUES ('10');

INSERT INTO schema_migrations (version) VALUES ('11');

INSERT INTO schema_migrations (version) VALUES ('12');

INSERT INTO schema_migrations (version) VALUES ('13');

INSERT INTO schema_migrations (version) VALUES ('14');

INSERT INTO schema_migrations (version) VALUES ('15');

INSERT INTO schema_migrations (version) VALUES ('16');

INSERT INTO schema_migrations (version) VALUES ('17');

INSERT INTO schema_migrations (version) VALUES ('18');

INSERT INTO schema_migrations (version) VALUES ('19');

INSERT INTO schema_migrations (version) VALUES ('2');

INSERT INTO schema_migrations (version) VALUES ('20');

INSERT INTO schema_migrations (version) VALUES ('20080901000000');

INSERT INTO schema_migrations (version) VALUES ('20080927145957');

INSERT INTO schema_migrations (version) VALUES ('20081015004825');

INSERT INTO schema_migrations (version) VALUES ('20081015004855');

INSERT INTO schema_migrations (version) VALUES ('20081015004938');

INSERT INTO schema_migrations (version) VALUES ('20081015005018');

INSERT INTO schema_migrations (version) VALUES ('20081015005051');

INSERT INTO schema_migrations (version) VALUES ('20081015005124');

INSERT INTO schema_migrations (version) VALUES ('20081015005201');

INSERT INTO schema_migrations (version) VALUES ('20081015005919');

INSERT INTO schema_migrations (version) VALUES ('20081015010657');

INSERT INTO schema_migrations (version) VALUES ('20081016002814');

INSERT INTO schema_migrations (version) VALUES ('20081018175545');

INSERT INTO schema_migrations (version) VALUES ('20081023224739');

INSERT INTO schema_migrations (version) VALUES ('20081024083115');

INSERT INTO schema_migrations (version) VALUES ('20081024223856');

INSERT INTO schema_migrations (version) VALUES ('20081025222424');

INSERT INTO schema_migrations (version) VALUES ('20081105030832');

INSERT INTO schema_migrations (version) VALUES ('20081122055610');

INSERT INTO schema_migrations (version) VALUES ('20081130190723');

INSERT INTO schema_migrations (version) VALUES ('20081130191226');

INSERT INTO schema_migrations (version) VALUES ('20081203035506');

INSERT INTO schema_migrations (version) VALUES ('20081204062728');

INSERT INTO schema_migrations (version) VALUES ('20081205061033');

INSERT INTO schema_migrations (version) VALUES ('20081205072029');

INSERT INTO schema_migrations (version) VALUES ('20081208220020');

INSERT INTO schema_migrations (version) VALUES ('20081209221550');

INSERT INTO schema_migrations (version) VALUES ('20081210193125');

INSERT INTO schema_migrations (version) VALUES ('20090115234541');

INSERT INTO schema_migrations (version) VALUES ('20090123212834');

INSERT INTO schema_migrations (version) VALUES ('20090208201752');

INSERT INTO schema_migrations (version) VALUES ('20090215000207');

INSERT INTO schema_migrations (version) VALUES ('20090903232732');

INSERT INTO schema_migrations (version) VALUES ('20091228170149');

INSERT INTO schema_migrations (version) VALUES ('20100101225942');

INSERT INTO schema_migrations (version) VALUES ('20100827031936');

INSERT INTO schema_migrations (version) VALUES ('20100831065951');

INSERT INTO schema_migrations (version) VALUES ('20100903220234');

INSERT INTO schema_migrations (version) VALUES ('20100906054326');

INSERT INTO schema_migrations (version) VALUES ('20100907042612');

INSERT INTO schema_migrations (version) VALUES ('20100907210915');

INSERT INTO schema_migrations (version) VALUES ('20100907215811');

INSERT INTO schema_migrations (version) VALUES ('20101011000658');

INSERT INTO schema_migrations (version) VALUES ('20101027013550');

INSERT INTO schema_migrations (version) VALUES ('20101116221443');

INSERT INTO schema_migrations (version) VALUES ('20101212021821');

INSERT INTO schema_migrations (version) VALUES ('20101218070942');

INSERT INTO schema_migrations (version) VALUES ('20110116202516');

INSERT INTO schema_migrations (version) VALUES ('20110228010717');

INSERT INTO schema_migrations (version) VALUES ('20120331040429');

INSERT INTO schema_migrations (version) VALUES ('20120505130017');

INSERT INTO schema_migrations (version) VALUES ('20120624121058');

INSERT INTO schema_migrations (version) VALUES ('20120723155345');

INSERT INTO schema_migrations (version) VALUES ('20120723161914');

INSERT INTO schema_migrations (version) VALUES ('20120804130515');

INSERT INTO schema_migrations (version) VALUES ('20120813155642');

INSERT INTO schema_migrations (version) VALUES ('20120830051636');

INSERT INTO schema_migrations (version) VALUES ('20120920171733');

INSERT INTO schema_migrations (version) VALUES ('20120920172947');

INSERT INTO schema_migrations (version) VALUES ('20120920173324');

INSERT INTO schema_migrations (version) VALUES ('20120920173803');

INSERT INTO schema_migrations (version) VALUES ('20120920174218');

INSERT INTO schema_migrations (version) VALUES ('20120921040720');

INSERT INTO schema_migrations (version) VALUES ('20130326154700');

INSERT INTO schema_migrations (version) VALUES ('20130326161630');

INSERT INTO schema_migrations (version) VALUES ('20140309152432');

INSERT INTO schema_migrations (version) VALUES ('20140427041839');

INSERT INTO schema_migrations (version) VALUES ('20140429125422');

INSERT INTO schema_migrations (version) VALUES ('21');

INSERT INTO schema_migrations (version) VALUES ('22');

INSERT INTO schema_migrations (version) VALUES ('23');

INSERT INTO schema_migrations (version) VALUES ('24');

INSERT INTO schema_migrations (version) VALUES ('25');

INSERT INTO schema_migrations (version) VALUES ('26');

INSERT INTO schema_migrations (version) VALUES ('27');

INSERT INTO schema_migrations (version) VALUES ('28');

INSERT INTO schema_migrations (version) VALUES ('29');

INSERT INTO schema_migrations (version) VALUES ('3');

INSERT INTO schema_migrations (version) VALUES ('30');

INSERT INTO schema_migrations (version) VALUES ('31');

INSERT INTO schema_migrations (version) VALUES ('32');

INSERT INTO schema_migrations (version) VALUES ('33');

INSERT INTO schema_migrations (version) VALUES ('34');

INSERT INTO schema_migrations (version) VALUES ('35');

INSERT INTO schema_migrations (version) VALUES ('36');

INSERT INTO schema_migrations (version) VALUES ('37');

INSERT INTO schema_migrations (version) VALUES ('38');

INSERT INTO schema_migrations (version) VALUES ('39');

INSERT INTO schema_migrations (version) VALUES ('4');

INSERT INTO schema_migrations (version) VALUES ('40');

INSERT INTO schema_migrations (version) VALUES ('41');

INSERT INTO schema_migrations (version) VALUES ('42');

INSERT INTO schema_migrations (version) VALUES ('43');

INSERT INTO schema_migrations (version) VALUES ('44');

INSERT INTO schema_migrations (version) VALUES ('45');

INSERT INTO schema_migrations (version) VALUES ('46');

INSERT INTO schema_migrations (version) VALUES ('47');

INSERT INTO schema_migrations (version) VALUES ('48');

INSERT INTO schema_migrations (version) VALUES ('49');

INSERT INTO schema_migrations (version) VALUES ('5');

INSERT INTO schema_migrations (version) VALUES ('50');

INSERT INTO schema_migrations (version) VALUES ('51');

INSERT INTO schema_migrations (version) VALUES ('52');

INSERT INTO schema_migrations (version) VALUES ('53');

INSERT INTO schema_migrations (version) VALUES ('54');

INSERT INTO schema_migrations (version) VALUES ('55');

INSERT INTO schema_migrations (version) VALUES ('56');

INSERT INTO schema_migrations (version) VALUES ('57');

INSERT INTO schema_migrations (version) VALUES ('58');

INSERT INTO schema_migrations (version) VALUES ('59');

INSERT INTO schema_migrations (version) VALUES ('6');

INSERT INTO schema_migrations (version) VALUES ('60');

INSERT INTO schema_migrations (version) VALUES ('61');

INSERT INTO schema_migrations (version) VALUES ('62');

INSERT INTO schema_migrations (version) VALUES ('63');

INSERT INTO schema_migrations (version) VALUES ('64');

INSERT INTO schema_migrations (version) VALUES ('65');

INSERT INTO schema_migrations (version) VALUES ('66');

INSERT INTO schema_migrations (version) VALUES ('67');

INSERT INTO schema_migrations (version) VALUES ('68');

INSERT INTO schema_migrations (version) VALUES ('69');

INSERT INTO schema_migrations (version) VALUES ('7');

INSERT INTO schema_migrations (version) VALUES ('70');

INSERT INTO schema_migrations (version) VALUES ('71');

INSERT INTO schema_migrations (version) VALUES ('72');

INSERT INTO schema_migrations (version) VALUES ('73');

INSERT INTO schema_migrations (version) VALUES ('74');

INSERT INTO schema_migrations (version) VALUES ('75');

INSERT INTO schema_migrations (version) VALUES ('76');

INSERT INTO schema_migrations (version) VALUES ('77');

INSERT INTO schema_migrations (version) VALUES ('78');

INSERT INTO schema_migrations (version) VALUES ('79');

INSERT INTO schema_migrations (version) VALUES ('8');

INSERT INTO schema_migrations (version) VALUES ('80');

INSERT INTO schema_migrations (version) VALUES ('81');

INSERT INTO schema_migrations (version) VALUES ('82');

INSERT INTO schema_migrations (version) VALUES ('83');

INSERT INTO schema_migrations (version) VALUES ('84');

INSERT INTO schema_migrations (version) VALUES ('85');

INSERT INTO schema_migrations (version) VALUES ('86');

INSERT INTO schema_migrations (version) VALUES ('87');

INSERT INTO schema_migrations (version) VALUES ('88');

INSERT INTO schema_migrations (version) VALUES ('89');

INSERT INTO schema_migrations (version) VALUES ('9');

INSERT INTO schema_migrations (version) VALUES ('90');

INSERT INTO schema_migrations (version) VALUES ('91');

INSERT INTO schema_migrations (version) VALUES ('9142010220946');

INSERT INTO schema_migrations (version) VALUES ('92');

INSERT INTO schema_migrations (version) VALUES ('93');

INSERT INTO schema_migrations (version) VALUES ('94');

INSERT INTO schema_migrations (version) VALUES ('95');

INSERT INTO schema_migrations (version) VALUES ('96');
