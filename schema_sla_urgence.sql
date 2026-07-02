-- ============================================================
-- Coris-Réclamations — SLA différencié selon l'urgence
-- À exécuter manuellement dans l'éditeur SQL du projet Supabase
-- ============================================================

-- Remplace la fonction existante : le SLA est maintenant de 24h pour
-- les réclamations urgentes et 48h pour les réclamations normales,
-- au lieu de 48h fixe pour toutes.

CREATE OR REPLACE FUNCTION generate_reclamation_reference()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  today_str  text := to_char(now(), 'YYYYMMDD');
  seq_num    int;
  sla_heures int;
BEGIN
  SELECT count(*) + 1 INTO seq_num
  FROM reclamations
  WHERE reference LIKE 'PL-' || today_str || '-%';

  sla_heures := CASE WHEN NEW.niveau_urgence = 'urgent' THEN 24 ELSE 48 END;

  NEW.reference         := 'PL-' || today_str || '-' || lpad(seq_num::text, 5, '0');
  NEW.sla_deadline       := now() + (sla_heures || ' hours')::interval;
  NEW.date_derniere_maj  := now();
  RETURN NEW;
END;
$$;
