-- ============================================================
-- Coris-Réclamations — Renforcement sécurité
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- ---------- 1. Les comptes désactivés perdent immédiatement le droit d'écriture ----------
-- Avant : is_admin / assigne_a suffisaient, actif n'était jamais vérifié en base
-- (un compte désactivé gardait ses droits jusqu'à expiration de son jeton, ~1h).
DROP POLICY IF EXISTS "staff_update_reclamation" ON reclamations;

CREATE POLICY "staff_update_reclamation" ON reclamations
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true AND actif = true)
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND actif = true AND nom = reclamations.assigne_a)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true AND actif = true)
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND actif = true AND nom = reclamations.assigne_a)
  );

CREATE OR REPLACE FUNCTION verifier_permission_maj_reclamation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  est_admin       boolean;
  nom_utilisateur text;
  est_actif       boolean;
BEGIN
  SELECT is_admin, nom, actif INTO est_admin, nom_utilisateur, est_actif FROM profiles WHERE id = auth.uid();

  IF NOT (COALESCE(est_admin, false) AND COALESCE(est_actif, false)) THEN
    IF NEW.assigne_a IS DISTINCT FROM OLD.assigne_a THEN
      RAISE EXCEPTION 'Seuls les administrateurs actifs peuvent réassigner une réclamation.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------- 2. Limites serveur sur le bucket Storage (pièces jointes) ----------
-- Avant : seule la validation côté client (JS) limitait taille/type — contournable
-- en appelant l'API Storage directement.
UPDATE storage.buckets
SET file_size_limit = 10485760, -- 10 Mo
    allowed_mime_types = ARRAY['image/*', 'application/pdf', 'video/*']
WHERE id = 'pieces-jointes';

-- ---------- 3. Garde-fou anti-flood sur le dépôt public de réclamations ----------
-- Limite globale grossière (pas par IP, simple à mettre en place) : bloque un flood
-- massif qui viderait le quota mensuel gratuit d'EmailJS (~200 emails), ce qui
-- couperait silencieusement les vraies notifications.
CREATE OR REPLACE FUNCTION soumettre_reclamation(
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
  IF (SELECT count(*) FROM reclamations WHERE date_creation > now() - interval '2 minutes') >= 20 THEN
    RAISE EXCEPTION 'Trop de réclamations déposées récemment, veuillez réessayer dans quelques instants.';
  END IF;

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
