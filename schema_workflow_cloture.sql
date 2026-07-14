-- ============================================================
-- Coris-Réclamations — Workflow de clôture et verrouillage
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- Règles ajoutées (en plus de celles déjà en place) :
--   1. Une réclamation "clos" devient totalement immuable (personne, y compris
--      les admins, ne peut plus la modifier).
--   2. Seuls les admins actifs peuvent faire passer une réclamation à "clos".
--   3. Le niveau d'urgence, fixé par le client à la création, n'est plus
--      modifiable par personne après coup.
CREATE OR REPLACE FUNCTION verifier_permission_maj_reclamation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  est_admin       boolean;
  nom_utilisateur text;
  est_actif       boolean;
BEGIN
  IF OLD.statut = 'clos' THEN
    RAISE EXCEPTION 'Cette réclamation est clôturée et ne peut plus être modifiée.';
  END IF;

  SELECT is_admin, nom, actif INTO est_admin, nom_utilisateur, est_actif FROM profiles WHERE id = auth.uid();

  IF NEW.niveau_urgence IS DISTINCT FROM OLD.niveau_urgence THEN
    RAISE EXCEPTION 'Le niveau d''urgence, défini par le client, ne peut pas être modifié.';
  END IF;

  IF NOT (COALESCE(est_admin, false) AND COALESCE(est_actif, false)) THEN
    IF NEW.assigne_a IS DISTINCT FROM OLD.assigne_a THEN
      RAISE EXCEPTION 'Seuls les administrateurs actifs peuvent réassigner une réclamation.';
    END IF;
    IF NEW.statut = 'clos' THEN
      RAISE EXCEPTION 'Seuls les administrateurs actifs peuvent clôturer une réclamation.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
