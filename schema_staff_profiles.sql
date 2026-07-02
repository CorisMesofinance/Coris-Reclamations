-- ============================================================
-- Coris-Réclamations — Profils staff assignables
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- (les comptes Auth correspondants doivent déjà exister)
-- ============================================================

INSERT INTO profiles (id, email, nom, role, actif, is_admin) VALUES
  ('cca645c4-ad81-4a63-b2da-8ecf870162db', 'rlingany@coris-mesofinance.com', 'Abdoul Razac LINGANY', 'DG', true, false),
  ('479f6ae6-31b4-4e07-91c4-e6e0e34bd6ac', 'wesmel@coris-mesofinance.com', 'Meless Wilfried ESMEL', 'DEX', true, false),
  ('727fe4f8-1a7a-49cc-a5d0-44459d1d243f', 'skouadio@coris-mesofinance.com', 'Melaine Sabou KOUADIO', 'Chef d''agence', true, false),
  ('c94f559b-8e9d-4b87-b8c1-f42603acdd2c', 'mdiomande@coris-mesofinance.com', 'Ben Mohamed DIOMANDE', 'Responsable Opération', true, false),
  ('30f810cf-b536-466a-9440-6c2d4116f60e', 'eniamkey@coris-mesofinance.com', 'Erika Desirée NIAMKEY', 'Responsable Juridique', true, false);
