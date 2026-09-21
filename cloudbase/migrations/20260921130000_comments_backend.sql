CREATE SEQUENCE IF NOT EXISTS public.comments_id_seq START WITH 33;
ALTER TABLE public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq');

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'comments_parent_id_fkey') THEN
    ALTER TABLE public.comments
      ADD CONSTRAINT comments_parent_id_fkey
      FOREIGN KEY (parent_id) REFERENCES public.comments (id)
      ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_comments_project_id ON public.comments (project_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_id ON public.comments (parent_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON public.comments (created_at DESC);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.comments TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.comments TO service_role;

DROP POLICY IF EXISTS comments_select_all ON public.comments;
CREATE POLICY comments_select_all ON public.comments FOR SELECT USING (true);

DROP POLICY IF EXISTS comments_write_admin ON public.comments;
CREATE POLICY comments_write_admin ON public.comments
  FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');
