-- ============================================================
-- Coris-Réclamations — Liste déroulante d'assignation
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- La policy existante "self_select_profile" ne permet à chaque
-- utilisateur de lire QUE son propre profil (auth.uid() = id).
-- Pour peupler la liste déroulante "Assigné à" avec l'ensemble
-- des collaborateurs actifs, tout utilisateur staff authentifié
-- doit pouvoir lire la liste complète des profils.

CREATE POLICY "staff_select_all_profiles" ON profiles
  FOR SELECT TO authenticated USING (true);
