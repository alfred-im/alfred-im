-- Smoke test: verifica connettività agente → piattaforma (RLS read-only anon)
CREATE TABLE public.platform_agent_smoke (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  label text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.platform_agent_smoke ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_read_smoke"
  ON public.platform_agent_smoke
  FOR SELECT
  TO anon
  USING (true);

INSERT INTO public.platform_agent_smoke (label)
VALUES ('cursor-agent-ok');
