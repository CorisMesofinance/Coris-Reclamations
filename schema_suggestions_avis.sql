-- ============================================================
-- Coris-Réclamations — Suggestions & Avis
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- ---------- Suggestions ----------
CREATE TABLE IF NOT EXISTS suggestions (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nom_client    text,
  agence        text,
  texte         text NOT NULL,
  date_creation timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_insert_suggestion" ON suggestions
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "staff_select_suggestion" ON suggestions
  FOR SELECT TO authenticated USING (true);

-- ---------- Avis ----------
CREATE TABLE IF NOT EXISTS avis (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nom_client    text,
  agence        text NOT NULL,
  note          smallint NOT NULL CHECK (note BETWEEN 1 AND 5),
  commentaire   text,
  date_creation timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE avis ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_insert_avis" ON avis
  FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "staff_select_avis" ON avis
  FOR SELECT TO authenticated USING (true);
