CREATE TABLE IF NOT EXISTS public.comments_self (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id VARCHAR(255) NOT NULL,
  parent_id BIGINT REFERENCES public.comments_self (id) ON DELETE CASCADE,
  nickname VARCHAR(255) NOT NULL DEFAULT 'guest',
  content TEXT NOT NULL,
  role VARCHAR(64) NOT NULL DEFAULT 'guest',
  created_at BIGINT NOT NULL,
  updated_at BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_comments_self_project_id ON public.comments_self (project_id);
CREATE INDEX IF NOT EXISTS idx_comments_self_parent_id ON public.comments_self (parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_self_created_at ON public.comments_self (created_at DESC);

ALTER TABLE public.comments_self ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.comments_self TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.comments_self TO service_role;

DROP POLICY IF EXISTS comments_self_select_all ON public.comments_self;
CREATE POLICY comments_self_select_all ON public.comments_self FOR SELECT USING (true);

DROP POLICY IF EXISTS comments_self_write_admin ON public.comments_self;
CREATE POLICY comments_self_write_admin ON public.comments_self
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
