-- ============================================================
-- Coris-Réclamations — Pièces jointes (Supabase Storage)
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- ---------- Bucket Storage (privé) ----------
INSERT INTO storage.buckets (id, name, public)
VALUES ('pieces-jointes', 'pieces-jointes', false)
ON CONFLICT (id) DO NOTHING;

-- Le client (anon) peut uploader dans ce bucket au moment du dépôt,
-- mais ne peut jamais lister ni relire ce qui s'y trouve.
CREATE POLICY "anon_upload_pieces_jointes" ON storage.objects
  FOR INSERT TO anon
  WITH CHECK (bucket_id = 'pieces-jointes');

-- Le staff authentifié peut lire (télécharger/prévisualiser via URL signée).
CREATE POLICY "staff_select_pieces_jointes" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'pieces-jointes');

-- ---------- Table de métadonnées ----------
CREATE TABLE IF NOT EXISTS pieces_jointes_reclamations (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reclamation_id  bigint NOT NULL REFERENCES reclamations(id) ON DELETE CASCADE,
  nom_fichier     text NOT NULL,
  storage_path    text NOT NULL,
  type_fichier    text NOT NULL CHECK (type_fichier IN ('image','pdf','video')),
  uploaded_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pieces_jointes_reclamations ENABLE ROW LEVEL SECURITY;

-- Pas de policy INSERT pour anon : l'ajout se fait uniquement via la
-- fonction SECURITY DEFINER soumettre_reclamation ci-dessous (même
-- pattern que pour la table reclamations elle-même).
CREATE POLICY "staff_select_pieces_jointes_meta" ON pieces_jointes_reclamations
  FOR SELECT TO authenticated USING (true);

-- ---------- Étendre soumettre_reclamation pour accepter les pièces jointes ----------
-- Le client uploade d'abord les fichiers dans le bucket Storage (anon),
-- puis appelle cette fonction avec la liste des fichiers uploadés
-- (nom_fichier, storage_path, type_fichier) ; la fonction crée la
-- réclamation ET les lignes pieces_jointes_reclamations dans la même
-- transaction, en connaissant l'id généré côté serveur.
DROP FUNCTION IF EXISTS soumettre_reclamation(text,text,text,text,text,text,text,text);

CREATE FUNCTION soumettre_reclamation(
  p_nom_client     text,
  p_telephone      text,
  p_email          text,
  p_numero_compte  text,
  p_agence         text,
  p_type_plainte   text,
  p_description    text,
  p_niveau_urgence text,
  p_pieces_jointes jsonb DEFAULT '[]'::jsonb
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reference text;
  v_id        bigint;
  piece       jsonb;
BEGIN
  INSERT INTO reclamations (nom_client, telephone, email, numero_compte, agence, type_plainte, description, niveau_urgence)
  VALUES (p_nom_client, p_telephone, NULLIF(p_email,''), NULLIF(p_numero_compte,''), p_agence, p_type_plainte, p_description, COALESCE(p_niveau_urgence,'normal'))
  RETURNING id, reference INTO v_id, v_reference;

  IF p_pieces_jointes IS NOT NULL THEN
    FOR piece IN SELECT * FROM jsonb_array_elements(p_pieces_jointes)
    LOOP
      INSERT INTO pieces_jointes_reclamations (reclamation_id, nom_fichier, storage_path, type_fichier)
      VALUES (v_id, piece->>'nom_fichier', piece->>'storage_path', piece->>'type_fichier');
    END LOOP;
  END IF;

  RETURN v_reference;
END;
$$;

REVOKE ALL ON FUNCTION soumettre_reclamation(text,text,text,text,text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION soumettre_reclamation(text,text,text,text,text,text,text,text,jsonb) TO anon;
