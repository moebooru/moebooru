SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: post_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.post_status AS ENUM (
    'deleted',
    'flagged',
    'pending',
    'active'
);


--
-- Name: get_new_tags(character varying[], character varying[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_new_tags(old_array character varying[], new_array character varying[]) RETURNS character varying[]
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

CREATE FUNCTION public.history_changes_index_trigger() RETURNS trigger
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

      new.value_array := string_to_array(indexed_value, ' ');

      RETURN new;
    END
    $$;


--
-- Name: join_string(character varying[], character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.join_string(words character varying[], delimitor character varying) RETURNS character varying
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

CREATE FUNCTION public.nat_sort(t text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      BEGIN
        return array_to_string(array(select nat_sort_pad((regexp_matches(t, '([0-9]+|[^0-9]+)', 'g'))[1])), '');
      END;
      $$;


--
-- Name: nat_sort_pad(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.nat_sort_pad(t text) RETURNS text
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

CREATE FUNCTION public.pools_posts_delete_trg() RETURNS trigger
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

CREATE FUNCTION public.pools_posts_insert_trg() RETURNS trigger
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

CREATE FUNCTION public.pools_posts_update_trg() RETURNS trigger
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

CREATE FUNCTION public.pools_search_update_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        new.search_index := to_tsvector('pg_catalog.english', replace_underscores(new.name) || ' ' || new.description);
        RETURN new;
      END
      $$;


--
-- Name: posts_tags_array_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posts_tags_array_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (TG_OP = 'INSERT') OR (NEW.cached_tags <> OLD.cached_tags) THEN
    NEW.tags_array := string_to_array(NEW.cached_tags, ' ');
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: replace_underscores(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.replace_underscores(s character varying) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
    AS $$
        BEGIN
          RETURN regexp_replace(s, '_', ' ', 'g');
        END;
      $$;


--
-- Name: trg_posts_tags__delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_posts_tags__delete() RETURNS trigger
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

CREATE FUNCTION public.trg_posts_tags__insert() RETURNS trigger
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

CREATE FUNCTION public.trg_purge_histories() RETURNS trigger
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

CREATE FUNCTION public.user_logs_touch(new_user_id integer, new_ip inet) RETURNS void
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


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: advertisements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.advertisements (
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

CREATE SEQUENCE public.advertisements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: advertisements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.advertisements_id_seq OWNED BY public.advertisements.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: artist_urls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artist_urls (
    id integer NOT NULL,
    artist_id integer NOT NULL,
    url text NOT NULL,
    normalized_url text NOT NULL
);


--
-- Name: artist_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artist_urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artist_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.artist_urls_id_seq OWNED BY public.artist_urls.id;


--
-- Name: artists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artists (
    id integer DEFAULT nextval('public.artists_id_seq'::regclass) NOT NULL,
    alias_id integer,
    group_id integer,
    name text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updater_id integer
);


--
-- Name: bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bans (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reason text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    banned_by integer NOT NULL,
    old_level integer
);


--
-- Name: bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bans_id_seq OWNED BY public.bans.id;


--
-- Name: batch_uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_uploads (
    id integer NOT NULL,
    user_id integer NOT NULL,
    ip inet,
    url text NOT NULL,
    tags character varying(255) DEFAULT ''::character varying NOT NULL,
    active boolean DEFAULT false NOT NULL,
    status character varying(255) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    data_as_json character varying(255) DEFAULT '{}'::character varying NOT NULL
);


--
-- Name: batch_uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.batch_uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: batch_uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.batch_uploads_id_seq OWNED BY public.batch_uploads.id;


--
-- Name: comment_fragments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_fragments (
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

CREATE SEQUENCE public.comment_fragments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_fragments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comment_fragments_id_seq OWNED BY public.comment_fragments.id;


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id integer DEFAULT nextval('public.comments_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    post_id integer NOT NULL,
    user_id integer,
    body text NOT NULL,
    ip_addr inet NOT NULL,
    is_spam boolean,
    text_search_index tsvector,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: dmails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dmails (
    id integer NOT NULL,
    from_id integer NOT NULL,
    to_id integer NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    has_seen boolean DEFAULT false NOT NULL,
    parent_id integer
);


--
-- Name: dmails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dmails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dmails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dmails_id_seq OWNED BY public.dmails.id;


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorites (
    id integer DEFAULT nextval('public.favorites_id_seq'::regclass) NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: flagged_post_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flagged_post_details (
    id integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    post_id integer NOT NULL,
    reason text NOT NULL,
    user_id integer,
    is_resolved boolean NOT NULL
);


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flagged_post_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flagged_post_details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flagged_post_details_id_seq OWNED BY public.flagged_post_details.id;


--
-- Name: forum_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_posts (
    id integer DEFAULT nextval('public.forum_posts_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
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

CREATE SEQUENCE public.forum_posts_user_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.histories (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id integer,
    group_by_id integer NOT NULL,
    group_by_table text NOT NULL,
    aux_as_json text
);


--
-- Name: histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.histories_id_seq OWNED BY public.histories.id;


--
-- Name: history_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.history_changes (
    id integer NOT NULL,
    column_name text NOT NULL,
    remote_id integer NOT NULL,
    table_name text NOT NULL,
    value text,
    history_id integer NOT NULL,
    previous_id integer,
    value_array character varying[]
);


--
-- Name: history_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.history_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: history_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.history_changes_id_seq OWNED BY public.history_changes.id;


--
-- Name: inline_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inline_images (
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

CREATE SEQUENCE public.inline_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inline_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inline_images_id_seq OWNED BY public.inline_images.id;


--
-- Name: inlines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inlines (
    id integer NOT NULL,
    user_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description text DEFAULT ''::text NOT NULL
);


--
-- Name: inlines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inlines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inlines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inlines_id_seq OWNED BY public.inlines.id;


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ip_bans (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    ip_addr inet NOT NULL,
    reason text NOT NULL,
    banned_by integer NOT NULL
);


--
-- Name: ip_bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ip_bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_bans_id_seq OWNED BY public.ip_bans.id;


--
-- Name: job_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_tasks (
    id integer NOT NULL,
    task_type character varying(255) NOT NULL,
    status character varying(255) NOT NULL,
    status_message text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    data jsonb,
    repeat_count integer DEFAULT 0 NOT NULL
);


--
-- Name: job_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_tasks_id_seq OWNED BY public.job_tasks.id;


--
-- Name: news_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.note_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_versions (
    id integer DEFAULT nextval('public.note_versions_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
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

CREATE SEQUENCE public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id integer DEFAULT nextval('public.notes_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
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
-- Name: pools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pools (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    user_id integer NOT NULL,
    is_public boolean DEFAULT true NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    zip_created_at timestamp with time zone,
    zip_is_warehoused boolean DEFAULT false NOT NULL,
    search_index tsvector
);


--
-- Name: pools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pools_id_seq OWNED BY public.pools.id;


--
-- Name: pools_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pools_posts (
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

CREATE SEQUENCE public.pools_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pools_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pools_posts_id_seq OWNED BY public.pools_posts.id;


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id integer DEFAULT nextval('public.posts_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    user_id integer,
    source text DEFAULT ''::text NOT NULL,
    md5 text NOT NULL,
    last_commented_at timestamp with time zone,
    rating character(1) DEFAULT 'q'::bpchar NOT NULL,
    width integer,
    height integer,
    is_warehoused boolean DEFAULT false NOT NULL,
    ip_addr inet NOT NULL,
    cached_tags text DEFAULT ''::text NOT NULL,
    is_note_locked boolean DEFAULT false NOT NULL,
    file_ext text DEFAULT ''::text NOT NULL,
    last_noted_at timestamp with time zone,
    is_rating_locked boolean DEFAULT false NOT NULL,
    parent_id integer,
    has_children boolean DEFAULT false NOT NULL,
    status public.post_status DEFAULT 'active'::public.post_status NOT NULL,
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
    index_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    is_shown_in_index boolean DEFAULT true NOT NULL,
    jpeg_width integer,
    jpeg_height integer,
    jpeg_size integer DEFAULT 0 NOT NULL,
    jpeg_crc32 bigint,
    frames text DEFAULT ''::text NOT NULL,
    frames_pending text DEFAULT ''::text NOT NULL,
    frames_warehoused boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone,
    tags_array character varying[]
);


--
-- Name: post_change_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_change_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_change_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_change_seq OWNED BY public.posts.change_seq;


--
-- Name: post_frames; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_frames (
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

CREATE SEQUENCE public.post_frames_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_frames_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_frames_id_seq OWNED BY public.post_frames.id;


--
-- Name: post_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tag_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_tag_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_tag_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_tag_histories (
    id integer DEFAULT nextval('public.post_tag_histories_id_seq'::regclass) NOT NULL,
    post_id integer NOT NULL,
    tags text NOT NULL,
    user_id integer,
    ip_addr inet,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: post_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_votes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    score integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: post_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_votes_id_seq OWNED BY public.post_votes.id;


--
-- Name: posts_id_seq2; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq2
    START WITH 7168
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts_tags (
    post_id integer NOT NULL,
    tag_id integer NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: table_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_data (
    name text NOT NULL,
    row_count integer NOT NULL
);


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_aliases (
    id integer DEFAULT nextval('public.tag_aliases_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    alias_id integer NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    creator_id integer
);


--
-- Name: tag_implications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_implications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_implications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_implications (
    id integer DEFAULT nextval('public.tag_implications_id_seq'::regclass) NOT NULL,
    consequent_id integer NOT NULL,
    predicate_id integer NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    creator_id integer
);


--
-- Name: tag_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_subscriptions (
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

CREATE SEQUENCE public.tag_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_subscriptions_id_seq OWNED BY public.tag_subscriptions.id;


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer DEFAULT nextval('public.tags_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    cached_related text DEFAULT '[]'::text NOT NULL,
    cached_related_expires_on timestamp with time zone DEFAULT now() NOT NULL,
    tag_type smallint DEFAULT 0 NOT NULL,
    is_ambiguous boolean DEFAULT false NOT NULL,
    safe_post_count integer DEFAULT 0 NOT NULL
);


--
-- Name: user_blacklisted_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blacklisted_tags (
    id integer NOT NULL,
    user_id integer NOT NULL,
    tags text NOT NULL
);


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_blacklisted_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_blacklisted_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_blacklisted_tags_id_seq OWNED BY public.user_blacklisted_tags.id;


--
-- Name: user_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_logs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ip_addr inet NOT NULL
);


--
-- Name: user_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_logs_id_seq OWNED BY public.user_logs.id;


--
-- Name: user_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_records (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reported_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_positive boolean DEFAULT true NOT NULL,
    body text NOT NULL
);


--
-- Name: user_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_records_id_seq OWNED BY public.user_records.id;


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
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer DEFAULT nextval('public.users_id_seq'::regclass) NOT NULL,
    name text NOT NULL,
    password_hash text NOT NULL,
    level integer DEFAULT 0 NOT NULL,
    email text DEFAULT ''::text NOT NULL,
    my_tags text DEFAULT ''::text NOT NULL,
    invite_count integer DEFAULT 0 NOT NULL,
    always_resize_images boolean DEFAULT false NOT NULL,
    invited_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_logged_in_at timestamp with time zone DEFAULT now() NOT NULL,
    last_forum_topic_read_at timestamp with time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
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
    avatar_timestamp timestamp with time zone,
    last_comment_read_at timestamp with time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
    last_deleted_post_seen_at timestamp with time zone DEFAULT '1960-01-01 00:00:00'::timestamp without time zone NOT NULL,
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

CREATE SEQUENCE public.wiki_page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_page_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_page_versions (
    id integer DEFAULT nextval('public.wiki_page_versions_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
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

CREATE SEQUENCE public.wiki_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_pages (
    id integer DEFAULT nextval('public.wiki_pages_id_seq'::regclass) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    user_id integer,
    ip_addr inet NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    text_search_index tsvector
);


--
-- Name: advertisements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.advertisements ALTER COLUMN id SET DEFAULT nextval('public.advertisements_id_seq'::regclass);


--
-- Name: artist_urls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_urls ALTER COLUMN id SET DEFAULT nextval('public.artist_urls_id_seq'::regclass);


--
-- Name: bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans ALTER COLUMN id SET DEFAULT nextval('public.bans_id_seq'::regclass);


--
-- Name: batch_uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_uploads ALTER COLUMN id SET DEFAULT nextval('public.batch_uploads_id_seq'::regclass);


--
-- Name: comment_fragments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_fragments ALTER COLUMN id SET DEFAULT nextval('public.comment_fragments_id_seq'::regclass);


--
-- Name: dmails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails ALTER COLUMN id SET DEFAULT nextval('public.dmails_id_seq'::regclass);


--
-- Name: flagged_post_details id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flagged_post_details ALTER COLUMN id SET DEFAULT nextval('public.flagged_post_details_id_seq'::regclass);


--
-- Name: histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.histories ALTER COLUMN id SET DEFAULT nextval('public.histories_id_seq'::regclass);


--
-- Name: history_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_changes ALTER COLUMN id SET DEFAULT nextval('public.history_changes_id_seq'::regclass);


--
-- Name: inline_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inline_images ALTER COLUMN id SET DEFAULT nextval('public.inline_images_id_seq'::regclass);


--
-- Name: inlines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inlines ALTER COLUMN id SET DEFAULT nextval('public.inlines_id_seq'::regclass);


--
-- Name: ip_bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_bans ALTER COLUMN id SET DEFAULT nextval('public.ip_bans_id_seq'::regclass);


--
-- Name: job_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_tasks ALTER COLUMN id SET DEFAULT nextval('public.job_tasks_id_seq'::regclass);


--
-- Name: pools id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools ALTER COLUMN id SET DEFAULT nextval('public.pools_id_seq'::regclass);


--
-- Name: pools_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools_posts ALTER COLUMN id SET DEFAULT nextval('public.pools_posts_id_seq'::regclass);


--
-- Name: post_frames id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_frames ALTER COLUMN id SET DEFAULT nextval('public.post_frames_id_seq'::regclass);


--
-- Name: post_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes ALTER COLUMN id SET DEFAULT nextval('public.post_votes_id_seq'::regclass);


--
-- Name: posts change_seq; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN change_seq SET DEFAULT nextval('public.post_change_seq'::regclass);


--
-- Name: tag_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.tag_subscriptions_id_seq'::regclass);


--
-- Name: user_blacklisted_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blacklisted_tags ALTER COLUMN id SET DEFAULT nextval('public.user_blacklisted_tags_id_seq'::regclass);


--
-- Name: user_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_logs ALTER COLUMN id SET DEFAULT nextval('public.user_logs_id_seq'::regclass);


--
-- Name: user_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_records ALTER COLUMN id SET DEFAULT nextval('public.user_records_id_seq'::regclass);


--
-- Name: advertisements advertisements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.advertisements
    ADD CONSTRAINT advertisements_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: artist_urls artist_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_urls
    ADD CONSTRAINT artist_urls_pkey PRIMARY KEY (id);


--
-- Name: artists artists_name_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_name_uniq UNIQUE (name);


--
-- Name: artists artists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_pkey PRIMARY KEY (id);


--
-- Name: bans bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans
    ADD CONSTRAINT bans_pkey PRIMARY KEY (id);


--
-- Name: batch_uploads batch_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_uploads
    ADD CONSTRAINT batch_uploads_pkey PRIMARY KEY (id);


--
-- Name: batch_uploads batch_uploads_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_uploads
    ADD CONSTRAINT batch_uploads_user_id_key UNIQUE (user_id, url);


--
-- Name: comment_fragments comment_fragments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_fragments
    ADD CONSTRAINT comment_fragments_pkey PRIMARY KEY (id);


--
-- Name: comment_fragments comment_fragments_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_fragments
    ADD CONSTRAINT comment_fragments_unique UNIQUE (comment_id, block_id, source_lang, target_lang);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: dmails dmails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT dmails_pkey PRIMARY KEY (id);


--
-- Name: tag_subscriptions favorite_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_subscriptions
    ADD CONSTRAINT favorite_tags_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: flagged_post_details flagged_post_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flagged_post_details
    ADD CONSTRAINT flagged_post_details_pkey PRIMARY KEY (id);


--
-- Name: forum_posts forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);


--
-- Name: histories histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.histories
    ADD CONSTRAINT histories_pkey PRIMARY KEY (id);


--
-- Name: history_changes history_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_changes
    ADD CONSTRAINT history_changes_pkey PRIMARY KEY (id);


--
-- Name: inline_images inline_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inline_images
    ADD CONSTRAINT inline_images_pkey PRIMARY KEY (id);


--
-- Name: inlines inlines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inlines
    ADD CONSTRAINT inlines_pkey PRIMARY KEY (id);


--
-- Name: ip_bans ip_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_bans
    ADD CONSTRAINT ip_bans_pkey PRIMARY KEY (id);


--
-- Name: job_tasks job_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_tasks
    ADD CONSTRAINT job_tasks_pkey PRIMARY KEY (id);


--
-- Name: note_versions note_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT note_versions_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: pools pools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools
    ADD CONSTRAINT pools_pkey PRIMARY KEY (id);


--
-- Name: pools_posts pools_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools_posts
    ADD CONSTRAINT pools_posts_pkey PRIMARY KEY (id);


--
-- Name: post_frames post_frames_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_frames
    ADD CONSTRAINT post_frames_pkey PRIMARY KEY (id);


--
-- Name: post_tag_histories post_tag_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tag_histories
    ADD CONSTRAINT post_tag_histories_pkey PRIMARY KEY (id);


--
-- Name: post_votes post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_pkey PRIMARY KEY (id);


--
-- Name: post_votes post_votes_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_user_id_key UNIQUE (user_id, post_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: table_data table_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_data
    ADD CONSTRAINT table_data_pkey PRIMARY KEY (name);


--
-- Name: tag_aliases tag_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT tag_aliases_pkey PRIMARY KEY (id);


--
-- Name: tag_implications tag_implications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT tag_implications_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);

ALTER TABLE public.tags CLUSTER ON tags_pkey;


--
-- Name: user_blacklisted_tags user_blacklisted_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blacklisted_tags
    ADD CONSTRAINT user_blacklisted_tags_pkey PRIMARY KEY (id);


--
-- Name: user_logs user_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_logs
    ADD CONSTRAINT user_logs_pkey PRIMARY KEY (id);


--
-- Name: user_logs user_logs_user_ip; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_logs
    ADD CONSTRAINT user_logs_user_ip UNIQUE (user_id, ip_addr);


--
-- Name: user_records user_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_records
    ADD CONSTRAINT user_records_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wiki_page_versions wiki_page_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT wiki_page_versions_pkey PRIMARY KEY (id);


--
-- Name: wiki_pages wiki_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages
    ADD CONSTRAINT wiki_pages_pkey PRIMARY KEY (id);


--
-- Name: comments_text_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_text_search_idx ON public.comments USING gin (text_search_index);


--
-- Name: forum_posts__parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX forum_posts__parent_id_idx ON public.forum_posts USING btree (parent_id) WHERE (parent_id IS NULL);


--
-- Name: forum_posts_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX forum_posts_search_idx ON public.forum_posts USING gin (text_search_index);


--
-- Name: idx_comments__post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_comments__post ON public.comments USING btree (post_id);


--
-- Name: idx_favorites__post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_favorites__post ON public.favorites USING btree (post_id);


--
-- Name: idx_favorites__user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_favorites__user ON public.favorites USING btree (user_id);


--
-- Name: idx_note_versions__post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_note_versions__post ON public.note_versions USING btree (post_id);


--
-- Name: idx_notes__note; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes__note ON public.note_versions USING btree (note_id);


--
-- Name: idx_notes__post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notes__post ON public.notes USING btree (post_id);


--
-- Name: idx_pools__name_nat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pools__name_nat ON public.pools USING btree (public.nat_sort(name));


--
-- Name: idx_pools_posts__sequence_nat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pools_posts__sequence_nat ON public.pools_posts USING btree (public.nat_sort(sequence));


--
-- Name: idx_post_tag_histories__post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_tag_histories__post ON public.post_tag_histories USING btree (post_id);


--
-- Name: idx_posts__created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts__created_at ON public.posts USING btree (created_at);


--
-- Name: idx_posts__last_commented_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts__last_commented_at ON public.posts USING btree (last_commented_at) WHERE (last_commented_at IS NOT NULL);


--
-- Name: idx_posts__last_noted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts__last_noted_at ON public.posts USING btree (last_noted_at) WHERE (last_noted_at IS NOT NULL);


--
-- Name: idx_posts__md5; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_posts__md5 ON public.posts USING btree (md5);


--
-- Name: idx_posts__user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts__user ON public.posts USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: idx_posts_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_parent_id ON public.posts USING btree (parent_id) WHERE (parent_id IS NOT NULL);


--
-- Name: idx_posts_tags__post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_tags__post ON public.posts_tags USING btree (post_id);


--
-- Name: idx_posts_tags__tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_tags__tag ON public.posts_tags USING btree (tag_id);


--
-- Name: idx_tag_aliases__name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tag_aliases__name ON public.tag_aliases USING btree (name);


--
-- Name: idx_tag_implications__child; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tag_implications__child ON public.tag_implications USING btree (predicate_id);


--
-- Name: idx_tag_implications__parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tag_implications__parent ON public.tag_implications USING btree (consequent_id);


--
-- Name: idx_tags__name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tags__name ON public.tags USING btree (name);


--
-- Name: idx_tags__post_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tags__post_count ON public.tags USING btree (post_count);


--
-- Name: idx_users__name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_users__name ON public.users USING btree (lower(name));


--
-- Name: idx_wiki_page_versions__wiki_page; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wiki_page_versions__wiki_page ON public.wiki_page_versions USING btree (wiki_page_id);


--
-- Name: idx_wiki_pages__title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_wiki_pages__title ON public.wiki_pages USING btree (title);


--
-- Name: idx_wiki_pages__updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wiki_pages__updated_at ON public.wiki_pages USING btree (updated_at);


--
-- Name: index_artist_urls_on_artist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_artist_id ON public.artist_urls USING btree (artist_id);


--
-- Name: index_artist_urls_on_normalized_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_normalized_url ON public.artist_urls USING btree (normalized_url);


--
-- Name: index_artist_urls_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_url ON public.artist_urls USING btree (url);


--
-- Name: index_bans_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bans_on_user_id ON public.bans USING btree (user_id);


--
-- Name: index_comment_fragments_on_comment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comment_fragments_on_comment_id ON public.comment_fragments USING btree (comment_id);


--
-- Name: index_dmails_on_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_from_id ON public.dmails USING btree (from_id);


--
-- Name: index_dmails_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_parent_id ON public.dmails USING btree (parent_id);


--
-- Name: index_dmails_on_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_to_id ON public.dmails USING btree (to_id);


--
-- Name: index_flagged_post_details_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flagged_post_details_on_created_at ON public.flagged_post_details USING btree (created_at);


--
-- Name: index_flagged_post_details_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flagged_post_details_on_post_id ON public.flagged_post_details USING btree (post_id);


--
-- Name: index_forum_posts_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_posts_on_updated_at ON public.forum_posts USING btree (updated_at);


--
-- Name: index_histories_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_histories_on_created_at ON public.histories USING btree (created_at);


--
-- Name: index_histories_on_group_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_histories_on_group_by_id ON public.histories USING btree (group_by_id);


--
-- Name: index_histories_on_group_by_table; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_histories_on_group_by_table ON public.histories USING btree (group_by_table);


--
-- Name: index_histories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_histories_on_user_id ON public.histories USING btree (user_id);


--
-- Name: index_history_changes_on_history_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_history_changes_on_history_id ON public.history_changes USING btree (history_id);


--
-- Name: index_history_changes_on_previous_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_history_changes_on_previous_id ON public.history_changes USING btree (previous_id);


--
-- Name: index_history_changes_on_remote_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_history_changes_on_remote_id ON public.history_changes USING btree (remote_id);


--
-- Name: index_history_changes_on_table_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_history_changes_on_table_name ON public.history_changes USING btree (table_name);


--
-- Name: index_history_changes_on_value_array; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_history_changes_on_value_array ON public.history_changes USING gin (value_array);


--
-- Name: index_inline_images_on_inline_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inline_images_on_inline_id ON public.inline_images USING btree (inline_id);


--
-- Name: index_ip_bans_on_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ip_bans_on_ip_addr ON public.ip_bans USING btree (ip_addr);


--
-- Name: index_note_versions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_note_versions_on_user_id ON public.note_versions USING btree (user_id);


--
-- Name: index_pools_posts_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_posts_on_active ON public.pools_posts USING btree (active);


--
-- Name: index_post_frames_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_frames_on_post_id ON public.post_frames USING btree (post_id);


--
-- Name: index_post_tag_histories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_tag_histories_on_user_id ON public.post_tag_histories USING btree (user_id);


--
-- Name: index_post_votes_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_votes_on_post_id ON public.post_votes USING btree (post_id);


--
-- Name: index_post_votes_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_votes_on_updated_at ON public.post_votes USING btree (updated_at);


--
-- Name: index_post_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_votes_on_user_id ON public.post_votes USING btree (user_id);


--
-- Name: index_posts_on_change_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_change_seq ON public.posts USING btree (change_seq);


--
-- Name: index_posts_on_height; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_height ON public.posts USING btree (height);


--
-- Name: index_posts_on_index_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_index_timestamp ON public.posts USING btree (index_timestamp);


--
-- Name: index_posts_on_is_held; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_is_held ON public.posts USING btree (is_held);


--
-- Name: index_posts_on_random; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_random ON public.posts USING btree (random);


--
-- Name: index_posts_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_source ON public.posts USING btree (source);


--
-- Name: index_posts_on_tags_array; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_tags_array ON public.posts USING gin (tags_array);


--
-- Name: index_posts_on_width; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_width ON public.posts USING btree (width);


--
-- Name: index_posts_tags_on_post_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_tags_on_post_id_and_tag_id ON public.posts_tags USING btree (post_id, tag_id);


--
-- Name: index_tag_subscriptions_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_subscriptions_on_name ON public.tag_subscriptions USING btree (name);


--
-- Name: index_tag_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_subscriptions_on_user_id ON public.tag_subscriptions USING btree (user_id);


--
-- Name: index_user_blacklisted_tags_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_blacklisted_tags_on_user_id ON public.user_blacklisted_tags USING btree (user_id);


--
-- Name: index_user_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_logs_on_user_id ON public.user_logs USING btree (user_id);


--
-- Name: index_users_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_api_key ON public.users USING btree (api_key);


--
-- Name: index_users_on_avatar_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_avatar_post_id ON public.users USING btree (avatar_post_id);


--
-- Name: notes_text_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notes_text_search_idx ON public.notes USING gin (text_search_index);


--
-- Name: pools_posts_pool_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pools_posts_pool_id_idx ON public.pools_posts USING btree (pool_id);


--
-- Name: pools_posts_post_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pools_posts_post_id_idx ON public.pools_posts USING btree (post_id);


--
-- Name: pools_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pools_user_id_idx ON public.pools USING btree (user_id);


--
-- Name: post_frames_out_of_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_frames_out_of_date ON public.posts USING btree (id) WHERE ((frames <> frames_pending) AND ((frames <> ''::text) OR (frames_pending <> ''::text)));


--
-- Name: post_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_search_idx ON public.pools USING gin (search_index);


--
-- Name: post_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_status_idx ON public.posts USING btree (status) WHERE (status < 'active'::public.post_status);


--
-- Name: posts_mpixels; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_mpixels ON public.posts USING btree (((((width * height))::numeric / 1000000.0)));


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


--
-- Name: user_logs_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_logs_created_at_idx ON public.user_logs USING btree (created_at);


--
-- Name: user_logs_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_logs_user_id_idx ON public.user_logs USING btree (user_id);


--
-- Name: wiki_pages_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX wiki_pages_search_idx ON public.wiki_pages USING gin (text_search_index);


--
-- Name: pools delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO public.pools DO ( DELETE FROM public.history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'pools'::text));
 DELETE FROM public.histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'pools'::text));
);


--
-- Name: pools_posts delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO public.pools_posts DO ( DELETE FROM public.history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'pools_posts'::text));
 DELETE FROM public.histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'pools_posts'::text));
);


--
-- Name: posts delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO public.posts DO ( DELETE FROM public.history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'posts'::text));
 DELETE FROM public.histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'posts'::text));
);


--
-- Name: tags delete_histories; Type: RULE; Schema: public; Owner: -
--

CREATE RULE delete_histories AS
    ON DELETE TO public.tags DO ( DELETE FROM public.history_changes
  WHERE ((history_changes.remote_id = old.id) AND (history_changes.table_name = 'tags'::text));
 DELETE FROM public.histories
  WHERE ((histories.group_by_id = old.id) AND (histories.group_by_table = 'tags'::text));
);


--
-- Name: pools_posts pools_posts_delete_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_delete_trg BEFORE DELETE ON public.pools_posts FOR EACH ROW EXECUTE PROCEDURE public.pools_posts_delete_trg();


--
-- Name: pools_posts pools_posts_insert_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_insert_trg BEFORE INSERT ON public.pools_posts FOR EACH ROW EXECUTE PROCEDURE public.pools_posts_insert_trg();


--
-- Name: pools_posts pools_posts_update_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER pools_posts_update_trg BEFORE UPDATE ON public.pools_posts FOR EACH ROW EXECUTE PROCEDURE public.pools_posts_update_trg();


--
-- Name: posts posts_tags_array_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_tags_array_update BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE PROCEDURE public.posts_tags_array_update();


--
-- Name: history_changes trg_cleanup_history; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cleanup_history AFTER DELETE ON public.history_changes FOR EACH ROW EXECUTE PROCEDURE public.trg_purge_histories();


--
-- Name: comments trg_comment_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_comment_search_update BEFORE INSERT OR UPDATE ON public.comments FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'body');


--
-- Name: forum_posts trg_forum_post_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_forum_post_search_update BEFORE INSERT OR UPDATE ON public.forum_posts FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'title', 'body');


--
-- Name: history_changes trg_history_changes_value_index_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_history_changes_value_index_update BEFORE INSERT OR UPDATE ON public.history_changes FOR EACH ROW EXECUTE PROCEDURE public.history_changes_index_trigger();


--
-- Name: notes trg_note_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_note_search_update BEFORE INSERT OR UPDATE ON public.notes FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'body');


--
-- Name: pools trg_pools_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pools_search_update BEFORE INSERT OR UPDATE ON public.pools FOR EACH ROW EXECUTE PROCEDURE public.pools_search_update_trigger();


--
-- Name: posts_tags trg_posts_tags__delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__delete BEFORE DELETE ON public.posts_tags FOR EACH ROW EXECUTE PROCEDURE public.trg_posts_tags__delete();


--
-- Name: posts_tags trg_posts_tags__insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_posts_tags__insert BEFORE INSERT ON public.posts_tags FOR EACH ROW EXECUTE PROCEDURE public.trg_posts_tags__insert();


--
-- Name: wiki_pages trg_wiki_page_search_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_wiki_page_search_update BEFORE INSERT OR UPDATE ON public.wiki_pages FOR EACH ROW EXECUTE PROCEDURE tsvector_update_trigger('text_search_index', 'pg_catalog.english', 'title', 'body');


--
-- Name: artist_urls artist_urls_artist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_urls
    ADD CONSTRAINT artist_urls_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artists(id);


--
-- Name: artists artists_alias_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_alias_id_fkey FOREIGN KEY (alias_id) REFERENCES public.artists(id) ON DELETE SET NULL;


--
-- Name: artists artists_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.artists(id) ON DELETE SET NULL;


--
-- Name: artists artists_updater_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_updater_id_fkey FOREIGN KEY (updater_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: bans bans_banned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans
    ADD CONSTRAINT bans_banned_by_fkey FOREIGN KEY (banned_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: bans bans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans
    ADD CONSTRAINT bans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: batch_uploads batch_uploads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_uploads
    ADD CONSTRAINT batch_uploads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: comment_fragments comment_fragments_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_fragments
    ADD CONSTRAINT comment_fragments_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id) ON DELETE CASCADE;


--
-- Name: dmails dmails_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT dmails_from_id_fkey FOREIGN KEY (from_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: dmails dmails_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT dmails_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.dmails(id);


--
-- Name: dmails dmails_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT dmails_to_id_fkey FOREIGN KEY (to_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: comments fk_comments__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_comments__post FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: comments fk_comments__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_comments__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: favorites fk_favorites__post ; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT "fk_favorites__post " FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: favorites fk_favorites__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT fk_favorites__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: note_versions fk_note_versions__note; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT fk_note_versions__note FOREIGN KEY (note_id) REFERENCES public.notes(id) ON DELETE CASCADE;


--
-- Name: note_versions fk_note_versions__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT fk_note_versions__post FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: note_versions fk_note_versions__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT fk_note_versions__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notes fk_notes__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_notes__post FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: notes fk_notes__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_notes__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: post_tag_histories fk_post_tag_histories__post; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tag_histories
    ADD CONSTRAINT fk_post_tag_histories__post FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts fk_posts__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_posts__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: posts_tags fk_posts_tags__tag; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts_tags
    ADD CONSTRAINT fk_posts_tags__tag FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: tag_aliases fk_tag_aliases__alias; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT fk_tag_aliases__alias FOREIGN KEY (alias_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: tag_implications fk_tag_implications__child; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_tag_implications__child FOREIGN KEY (predicate_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: tag_implications fk_tag_implications__parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_tag_implications__parent FOREIGN KEY (consequent_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: wiki_page_versions fk_wiki_page_versions__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT fk_wiki_page_versions__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: wiki_page_versions fk_wiki_page_versions__wiki_page; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT fk_wiki_page_versions__wiki_page FOREIGN KEY (wiki_page_id) REFERENCES public.wiki_pages(id) ON DELETE CASCADE;


--
-- Name: wiki_pages fk_wiki_pages__user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages
    ADD CONSTRAINT fk_wiki_pages__user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: flagged_post_details flagged_post_details_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flagged_post_details
    ADD CONSTRAINT flagged_post_details_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: flagged_post_details flagged_post_details_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flagged_post_details
    ADD CONSTRAINT flagged_post_details_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: forum_posts forum_posts_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: forum_posts forum_posts_last_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_last_updated_by_fkey FOREIGN KEY (last_updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: forum_posts forum_posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.forum_posts(id) ON DELETE CASCADE;


--
-- Name: history_changes history_changes_history_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_changes
    ADD CONSTRAINT history_changes_history_id_fkey FOREIGN KEY (history_id) REFERENCES public.histories(id) ON DELETE CASCADE;


--
-- Name: history_changes history_changes_previous_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.history_changes
    ADD CONSTRAINT history_changes_previous_id_fkey FOREIGN KEY (previous_id) REFERENCES public.history_changes(id) ON DELETE SET NULL;


--
-- Name: inline_images inline_images_inline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inline_images
    ADD CONSTRAINT inline_images_inline_id_fkey FOREIGN KEY (inline_id) REFERENCES public.inlines(id) ON DELETE CASCADE;


--
-- Name: inlines inlines_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inlines
    ADD CONSTRAINT inlines_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: pools_posts pools_posts_next_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools_posts
    ADD CONSTRAINT pools_posts_next_post_id_fkey FOREIGN KEY (next_post_id) REFERENCES public.posts(id) ON DELETE SET NULL;


--
-- Name: pools_posts pools_posts_pool_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools_posts
    ADD CONSTRAINT pools_posts_pool_id_fkey FOREIGN KEY (pool_id) REFERENCES public.pools(id) ON DELETE CASCADE;


--
-- Name: pools_posts pools_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools_posts
    ADD CONSTRAINT pools_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: pools_posts pools_posts_prev_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools_posts
    ADD CONSTRAINT pools_posts_prev_post_id_fkey FOREIGN KEY (prev_post_id) REFERENCES public.posts(id) ON DELETE SET NULL;


--
-- Name: pools pools_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools
    ADD CONSTRAINT pools_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_frames post_frames_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_frames
    ADD CONSTRAINT post_frames_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tag_histories post_tag_histories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_tag_histories
    ADD CONSTRAINT post_tag_histories_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: post_votes post_votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_votes post_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: posts posts_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: posts posts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.posts(id) ON DELETE SET NULL;


--
-- Name: posts_tags posts_tags_post_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts_tags
    ADD CONSTRAINT posts_tags_post_id_fk FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: tag_aliases tag_aliases_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT tag_aliases_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tag_implications tag_implications_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT tag_implications_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tag_subscriptions tag_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_subscriptions
    ADD CONSTRAINT tag_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_blacklisted_tags user_blacklisted_tags_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blacklisted_tags
    ADD CONSTRAINT user_blacklisted_tags_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_logs user_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_logs
    ADD CONSTRAINT user_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_records user_records_reported_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_records
    ADD CONSTRAINT user_records_reported_by_fkey FOREIGN KEY (reported_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_records user_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_records
    ADD CONSTRAINT user_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_avatar_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_avatar_post_id_fkey FOREIGN KEY (avatar_post_id) REFERENCES public.posts(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('1'),
('10'),
('11'),
('12'),
('13'),
('14'),
('15'),
('16'),
('17'),
('18'),
('19'),
('2'),
('20'),
('20080901000000'),
('20080927145957'),
('20081015004825'),
('20081015004855'),
('20081015004938'),
('20081015005018'),
('20081015005051'),
('20081015005124'),
('20081015005201'),
('20081015005919'),
('20081015010657'),
('20081016002814'),
('20081018175545'),
('20081023224739'),
('20081024083115'),
('20081024223856'),
('20081025222424'),
('20081105030832'),
('20081122055610'),
('20081130190723'),
('20081130191226'),
('20081203035506'),
('20081204062728'),
('20081205061033'),
('20081205072029'),
('20081208220020'),
('20081209221550'),
('20081210193125'),
('20090115234541'),
('20090123212834'),
('20090208201752'),
('20090215000207'),
('20090903232732'),
('20091228170149'),
('20100101225942'),
('20100827031936'),
('20100831065951'),
('20100903220234'),
('20100906054326'),
('20100907042612'),
('20100907210915'),
('20100907215811'),
('20101011000658'),
('20101027013550'),
('20101116221443'),
('20101212021821'),
('20101218070942'),
('20110116202516'),
('20110228010717'),
('20120331040429'),
('20120505130017'),
('20120624121058'),
('20120723155345'),
('20120723161914'),
('20120804130515'),
('20120813155642'),
('20120830051636'),
('20120920171733'),
('20120920172947'),
('20120920173324'),
('20120920173803'),
('20120920174218'),
('20120921040720'),
('20130326154700'),
('20130326161630'),
('20140309152432'),
('20140427041839'),
('20140429125422'),
('20140905023318'),
('20151207113346'),
('20160113112901'),
('20160329065325'),
('20160329065802'),
('20160329154133'),
('20160329160235'),
('20160329161636'),
('20160330063707'),
('20180624074601'),
('21'),
('22'),
('23'),
('24'),
('25'),
('26'),
('27'),
('28'),
('29'),
('3'),
('30'),
('31'),
('32'),
('33'),
('34'),
('35'),
('36'),
('37'),
('38'),
('39'),
('4'),
('40'),
('41'),
('42'),
('43'),
('44'),
('45'),
('46'),
('47'),
('48'),
('49'),
('5'),
('50'),
('51'),
('52'),
('53'),
('54'),
('55'),
('56'),
('57'),
('58'),
('59'),
('6'),
('60'),
('61'),
('62'),
('63'),
('64'),
('65'),
('66'),
('67'),
('68'),
('69'),
('7'),
('70'),
('71'),
('72'),
('73'),
('74'),
('75'),
('76'),
('77'),
('78'),
('79'),
('8'),
('80'),
('81'),
('82'),
('83'),
('84'),
('85'),
('86'),
('87'),
('88'),
('89'),
('9'),
('90'),
('91'),
('9142010220946'),
('92'),
('93'),
('94'),
('95'),
('96');


