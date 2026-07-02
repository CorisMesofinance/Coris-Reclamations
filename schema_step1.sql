-- ============================================================
-- Coris-Réclamations — Schéma étape 1
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- DÉDIÉ à Coris-Réclamations (ne pas exécuter sur un autre projet)
-- ============================================================

-- ---------- Table principale ----------
CREATE TABLE IF NOT EXISTS reclamations (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reference         text UNIQUE,
  nom_client        text NOT NULL,
  telephone         text NOT NULL,
  email             text,
  numero_compte     text,
  agence            text NOT NULL,
  type_plainte      text NOT NULL CHECK (type_plainte IN ('accueil','credit','epargne','mobile_money','personnel','autre')),
  description       text NOT NULL,
  statut            text NOT NULL DEFAULT 'nouveau' CHECK (statut IN ('nouveau','assigne','pris_en_charge','en_traitement','resolu','clos')),
  assigne_a         text,
  niveau_urgence    text NOT NULL DEFAULT 'normal' CHECK (niveau_urgence IN ('normal','urgent')),
  date_creation     timestamptz NOT NULL DEFAULT now(),
  date_derniere_maj timestamptz,
  sla_deadline      timestamptz,
  historique        jsonb NOT NULL DEFAULT '[]'
);

CREATE INDEX IF NOT EXISTS idx_reclamations_statut ON reclamations (statut);
CREATE INDEX IF NOT EXISTS idx_reclamations_date_creation ON reclamations (date_creation);

-- ---------- Table des profils staff ----------
CREATE TABLE IF NOT EXISTS profiles (
  id       uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email    text,
  nom      text,
  role     text,
  actif    boolean NOT NULL DEFAULT true,
  is_admin boolean NOT NULL DEFAULT false
);

-- ---------- Génération auto référence + échéance SLA ----------
CREATE OR REPLACE FUNCTION generate_reclamation_reference()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  today_str text := to_char(now(), 'YYYYMMDD');
  seq_num   int;
BEGIN
  SELECT count(*) + 1 INTO seq_num
  FROM reclamations
  WHERE reference LIKE 'PL-' || today_str || '-%';

  NEW.reference         := 'PL-' || today_str || '-' || lpad(seq_num::text, 5, '0');
  NEW.sla_deadline       := now() + interval '48 hours';
  NEW.date_derniere_maj  := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_reclamation_reference ON reclamations;
CREATE TRIGGER trg_generate_reclamation_reference
BEFORE INSERT ON reclamations
FOR EACH ROW EXECUTE FUNCTION generate_reclamation_reference();

-- ---------- Dépôt public sécurisé (RPC, sans accès table direct pour anon) ----------
-- Le formulaire public appelle cette fonction plutôt que d'insérer directement
-- dans la table : elle ne renvoie que la référence générée, jamais les autres
-- réclamations (pas de fuite de données clients).
CREATE OR REPLACE FUNCTION soumettre_reclamation(
  p_nom_client     text,
  p_telephone      text,
  p_email          text,
  p_numero_compte  text,
  p_agence         text,
  p_type_plainte   text,
  p_description    text,
  p_niveau_urgence text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reference text;
BEGIN
  INSERT INTO reclamations (nom_client, telephone, email, numero_compte, agence, type_plainte, description, niveau_urgence)
  VALUES (p_nom_client, p_telephone, NULLIF(p_email,''), NULLIF(p_numero_compte,''), p_agence, p_type_plainte, p_description, COALESCE(p_niveau_urgence,'normal'))
  RETURNING reference INTO v_reference;

  RETURN v_reference;
END;
$$;

REVOKE ALL ON FUNCTION soumettre_reclamation(text,text,text,text,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION soumettre_reclamation(text,text,text,text,text,text,text,text) TO anon;

-- ---------- RLS ----------
ALTER TABLE reclamations ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Aucune policy INSERT pour anon : le dépôt public passe uniquement par la
-- fonction SECURITY DEFINER ci-dessus (qui contourne RLS car exécutée par le
-- propriétaire de la table), donc anon n'a et ne doit avoir aucun accès direct.

CREATE POLICY "staff_select_reclamation" ON reclamations
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "staff_update_reclamation" ON reclamations
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "self_select_profile" ON profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

-- ============================================================
-- Après exécution : créer les comptes staff manuellement dans
-- Supabase (Authentication > Users), puis ajouter la ligne
-- correspondante dans `profiles` (id = uuid de l'utilisateur créé) :
--
-- INSERT INTO profiles (id, email, nom, role, actif, is_admin)
-- VALUES ('<uuid-auth-user>', 'email@coris-mesofinance.com', 'Nom Prénom', 'admin', true, true);
-- ============================================================
