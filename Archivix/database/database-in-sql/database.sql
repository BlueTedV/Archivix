-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.api_tokens (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  name character varying NOT NULL DEFAULT 'mobile'::character varying,
  token_hash character varying NOT NULL UNIQUE,
  last_used_at timestamp without time zone,
  expires_at timestamp without time zone,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  CONSTRAINT api_tokens_pkey PRIMARY KEY (id)
);
CREATE TABLE public.cache (
  key character varying NOT NULL,
  value text NOT NULL,
  expiration integer NOT NULL,
  CONSTRAINT cache_pkey PRIMARY KEY (key)
);
CREATE TABLE public.cache_locks (
  key character varying NOT NULL,
  owner character varying NOT NULL,
  expiration integer NOT NULL,
  CONSTRAINT cache_locks_pkey PRIMARY KEY (key)
);
CREATE TABLE public.categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.email_verification_codes (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  code character varying NOT NULL,
  expires_at timestamp without time zone NOT NULL,
  used_at timestamp without time zone,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  CONSTRAINT email_verification_codes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.failed_jobs (
  id bigint NOT NULL DEFAULT nextval('failed_jobs_id_seq'::regclass),
  uuid character varying NOT NULL UNIQUE,
  connection text NOT NULL,
  queue text NOT NULL,
  payload text NOT NULL,
  exception text NOT NULL,
  failed_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT failed_jobs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.job_batches (
  id character varying NOT NULL,
  name character varying NOT NULL,
  total_jobs integer NOT NULL,
  pending_jobs integer NOT NULL,
  failed_jobs integer NOT NULL,
  failed_job_ids text NOT NULL,
  options text,
  cancelled_at integer,
  created_at integer NOT NULL,
  finished_at integer,
  CONSTRAINT job_batches_pkey PRIMARY KEY (id)
);
CREATE TABLE public.jobs (
  id bigint NOT NULL DEFAULT nextval('jobs_id_seq'::regclass),
  queue character varying NOT NULL,
  payload text NOT NULL,
  attempts smallint NOT NULL,
  reserved_at integer,
  available_at integer NOT NULL,
  created_at integer NOT NULL,
  CONSTRAINT jobs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.migrations (
  id integer NOT NULL DEFAULT nextval('migrations_id_seq'::regclass),
  migration character varying NOT NULL,
  batch integer NOT NULL,
  CONSTRAINT migrations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.paper_authors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  paper_id uuid NOT NULL,
  name text NOT NULL,
  email text,
  affiliation text,
  author_order integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT paper_authors_pkey PRIMARY KEY (id),
  CONSTRAINT paper_authors_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.papers(id)
);
CREATE TABLE public.paper_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  paper_id uuid,
  user_id uuid NOT NULL,
  author_label text NOT NULL,
  body text NOT NULL CHECK (char_length(btrim(body)) > 0 AND char_length(body) <= 2000),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  post_id uuid,
  parent_comment_id uuid,
  CONSTRAINT paper_comments_pkey PRIMARY KEY (id),
  CONSTRAINT paper_comments_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.papers(id),
  CONSTRAINT paper_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT paper_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT paper_comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.paper_comments(id)
);
CREATE TABLE public.comment_reactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  comment_id uuid NOT NULL,
  user_id uuid NOT NULL,
  reaction_value smallint NOT NULL CHECK (reaction_value = ANY (ARRAY['-1'::integer, 1])),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT comment_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT comment_reactions_comment_id_user_id_key UNIQUE (comment_id, user_id),
  CONSTRAINT comment_reactions_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.paper_comments(id),
  CONSTRAINT comment_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.paper_versions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  paper_id uuid NOT NULL,
  version_number integer NOT NULL,
  title text NOT NULL,
  abstract text NOT NULL DEFAULT ''::text,
  category_id uuid,
  category_name text,
  pdf_url text,
  pdf_file_name text,
  pdf_file_size bigint,
  authors_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb,
  owner_user_id uuid NOT NULL,
  editor_user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT paper_versions_pkey PRIMARY KEY (id),
  CONSTRAINT paper_versions_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.papers(id),
  CONSTRAINT paper_versions_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id),
  CONSTRAINT paper_versions_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id),
  CONSTRAINT paper_versions_editor_user_id_fkey FOREIGN KEY (editor_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.papers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  abstract text NOT NULL,
  category_id uuid NOT NULL,
  user_id uuid NOT NULL,
  pdf_url text,
  pdf_file_name text,
  pdf_file_size bigint,
  status text NOT NULL DEFAULT 'draft'::text CHECK (status = ANY (ARRAY['draft'::text, 'submitted'::text, 'under_review'::text, 'published'::text, 'rejected'::text])),
  views_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  published_at timestamp with time zone,
  submitted_at timestamp with time zone,
  reviewed_at timestamp with time zone,
  reviewed_by uuid,
  rejection_reason text,
  CONSTRAINT papers_pkey PRIMARY KEY (id),
  CONSTRAINT papers_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id),
  CONSTRAINT papers_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.password_reset_tokens (
  email character varying NOT NULL,
  token character varying NOT NULL,
  created_at timestamp without time zone,
  CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email)
);
CREATE TABLE public.post_attachments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  file_url text NOT NULL,
  file_name text NOT NULL,
  file_type text NOT NULL,
  file_size bigint,
  mime_type text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_attachments_pkey PRIMARY KEY (id),
  CONSTRAINT post_attachments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.post_reactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid,
  user_id uuid NOT NULL,
  reaction_value smallint NOT NULL CHECK (reaction_value = ANY (ARRAY['-1'::integer, 1])),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  paper_id uuid,
  CONSTRAINT post_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT post_reactions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT post_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_reactions_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.papers(id)
);
CREATE TABLE public.post_versions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  version_number integer NOT NULL,
  title text NOT NULL,
  content text NOT NULL DEFAULT ''::text,
  category_id uuid,
  category_name text,
  attachments_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb,
  owner_user_id uuid NOT NULL,
  editor_user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT post_versions_pkey PRIMARY KEY (id),
  CONSTRAINT post_versions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT post_versions_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id),
  CONSTRAINT post_versions_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES auth.users(id),
  CONSTRAINT post_versions_editor_user_id_fkey FOREIGN KEY (editor_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  category_id uuid NOT NULL,
  views_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT posts_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text CHECK (username IS NULL OR username ~ '^[A-Za-z0-9_]{3,24}$'::text),
  full_name text CHECK (full_name IS NULL OR char_length(full_name) <= 80),
  bio text CHECK (bio IS NULL OR char_length(bio) <= 240),
  avatar_path text,
  is_verified_professor boolean NOT NULL DEFAULT false,
  professor_institution text,
  professor_position text,
  professor_department text,
  professor_verified_at timestamp with time zone,
  professor_verified_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT profiles_professor_verified_by_fkey FOREIGN KEY (professor_verified_by) REFERENCES auth.users(id)
);
CREATE TABLE public.professor_verification_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  legal_name text NOT NULL CHECK (char_length(btrim(legal_name)) >= 2 AND char_length(btrim(legal_name)) <= 160),
  institution text NOT NULL CHECK (char_length(btrim(institution)) >= 2 AND char_length(btrim(institution)) <= 180),
  institutional_email text NOT NULL CHECK (POSITION(('@'::text) IN (institutional_email)) > 1 AND POSITION(('.'::text) IN (split_part(institutional_email, '@'::text, 2))) > 1),
  academic_position text NOT NULL CHECK (char_length(btrim(academic_position)) >= 2 AND char_length(btrim(academic_position)) <= 120),
  department text NOT NULL CHECK (char_length(btrim(department)) >= 2 AND char_length(btrim(department)) <= 160),
  proof_type text NOT NULL,
  proof_file_path text NOT NULL,
  notes text CHECK (notes IS NULL OR char_length(notes) <= 600),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  admin_notes text CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 600),
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT professor_verification_requests_pkey PRIMARY KEY (id),
  CONSTRAINT professor_verification_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT professor_verification_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id)
);
CREATE TABLE public.sessions (
  id character varying NOT NULL,
  user_id uuid,
  ip_address character varying,
  user_agent text,
  payload text NOT NULL,
  last_activity integer NOT NULL,
  CONSTRAINT sessions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  name character varying,
  email character varying NOT NULL UNIQUE,
  email_verified_at timestamp without time zone,
  password character varying NOT NULL,
  remember_token character varying,
  created_at timestamp without time zone,
  updated_at timestamp without time zone,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
