-- ============================================================
-- Coris-Réclamations — Permissions d'assignation
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- ---------- Étendre le rôle admin à LINGANY et ESMEL ----------
-- (Badra Ali COULIBALY est déjà admin depuis la création du premier compte)
UPDATE profiles SET is_admin = true
WHERE id IN (
  'cca645c4-ad81-4a63-b2da-8ecf870162db', -- Abdoul Razac LINGANY
  '479f6ae6-31b4-4e07-91c4-e6e0e34bd6ac'  -- Meless Wilfried ESMEL
);

-- ---------- RLS : restreindre la modification aux admins et aux réclamations assignées ----------
-- Le SELECT reste ouvert à tous les profils staff (tout le monde voit tout).
DROP POLICY IF EXISTS "staff_update_reclamation" ON reclamations;

CREATE POLICY "staff_update_reclamation" ON reclamations
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    OR assigne_a = (SELECT nom FROM profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    OR assigne_a = (SELECT nom FROM profiles WHERE id = auth.uid())
  );

-- ---------- Trigger : seuls les admins peuvent changer l'assignation ----------
CREATE OR REPLACE FUNCTION verifier_permission_maj_reclamation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  est_admin       boolean;
  nom_utilisateur text;
BEGIN
  SELECT is_admin, nom INTO est_admin, nom_utilisateur FROM profiles WHERE id = auth.uid();

  IF NOT COALESCE(est_admin, false) THEN
    IF NEW.assigne_a IS DISTINCT FROM OLD.assigne_a THEN
      RAISE EXCEPTION 'Seuls les administrateurs peuvent réassigner une réclamation.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_verifier_permission_maj ON reclamations;
CREATE TRIGGER trg_verifier_permission_maj
BEFORE UPDATE ON reclamations
FOR EACH ROW EXECUTE FUNCTION verifier_permission_maj_reclamation();
