# Contexte projet — Coris-Réclamations

Plateforme de recueil et de suivi des réclamations clients pour Coris Mésofinance Côte d'Ivoire. Portée : version complète (formulaire public, workflow, KPI, SLA, notifications, QR code).

## Porteur du projet
COULIBALY Badra Ali, Responsable Commercial. Hiérarchie : Chef d'agence KOUADIO SABOU MELAINE, DEX ESMEL WILFRED, DG LINGANY ABDOUL.

## Stack technique
- Frontend : `index.html` unique (HTML/CSS/JS vanilla), même pattern que Coris-Point-Hebdo et CréditTrack-Coris
- Backend : Supabase (nouveau compte/projet dédié — ne pas réutiliser celui des autres apps)
- Stockage fichiers : Supabase Storage (bucket `pieces-jointes`) — **contrairement aux autres apps Coris**, ici on stocke réellement les pièces jointes (photos, PDF, vidéos) car ce sont des preuves client, pas de restriction "trace documentaire uniquement"
- Hébergement : GitHub Pages, dépôt `CorisMesofinance/Coris-Reclamations` (compte GitHub dédié à l'entreprise, `bcoulibaly@coris-mesofinance.com`) — prod : https://corismesofinance.github.io/Coris-Reclamations/
- Notifications email/SMS : via Supabase Edge Function (jamais de clé API de service tiers exposée côté client)
- Couleurs Coris : navy `#1A3A7A`, bleu `#1A5CA8`, gold `#C8A84B`, rouge `#CC0000`. Police Inter.

## Architecture base de données (proposition — à valider avant création)

### Table `reclamations`
```
id                  bigint PK
reference           text unique   -- format PL-YYYYMMDD-00001
nom_client          text
telephone           text
email               text nullable
numero_compte       text nullable
agence              text
type_plainte        text          -- accueil / credit / epargne / mobile_money / personnel / autre
description         text
statut              text default 'nouveau'  -- nouveau / assigne / pris_en_charge / en_traitement / resolu / clos
assigne_a           text nullable -- service ou personne
niveau_urgence      text default 'normal'   -- normal / urgent
date_creation       timestamptz default now()
date_derniere_maj   timestamptz
sla_deadline        timestamptz   -- date_creation + 48h, calculé à la création
historique          jsonb default '[]'  -- même logique que statut_historique sur les autres apps
```

### Table `pieces_jointes_reclamations`
```
id              bigint PK
reclamation_id  bigint FK -> reclamations.id
nom_fichier     text
storage_path    text      -- chemin dans le bucket Supabase Storage
type_fichier    text      -- image / pdf / video
uploaded_at     timestamptz default now()
```

### Table `commentaires_reclamations`
```
id              bigint PK
reclamation_id  bigint FK -> reclamations.id
auteur          text
commentaire     text
created_at      timestamptz default now()
```

### Table `profiles` (staff uniquement — les clients ne se connectent jamais)
Même structure que les autres apps : `id, email, nom, role, actif, is_admin`. Rôles envisagés : `admin`, `chef_agence`, `dex`, `service_juridique`, `resp_exploitation`.

## Workflow des statuts
```
nouveau → assigné → pris_en_charge → en_traitement → résolu → clos
```
Chaque transition : horodatée, enregistrée dans `historique` (même pattern JSONB que `statut_historique` des autres apps), déclenche un email au responsable assigné.

## SLA
- Délai cible : 48h → au-delà, ligne affichée en orange dans le tableau
- 72h → ligne en rouge + relance automatique (email) au responsable assigné
- Calcul du dépassement fait côté client (JS) à l'affichage — pas besoin de cron pour l'affichage visuel
- La relance automatique à 72h nécessite en revanche une tâche planifiée côté Supabase (pg_cron + Edge Function) — à construire en dernière phase

## Accès public (formulaire client)
- Page accessible sans authentification (RLS Supabase : INSERT autorisé à tous sur `reclamations`, SELECT/UPDATE/DELETE réservés aux rôles staff authentifiés)
- Protection anti-spam à prévoir (a minima un simple honeypot ou reCAPTCHA — à discuter avant mise en prod publique)
- QR Code : génère un lien direct vers le formulaire (peut être un simple générateur QR côté client, ex. bibliothèque JS, pointant vers l'URL GitHub Pages)

## Notifications (phase à construire après le cœur applicatif)
- Email au responsable à la création d'une plainte et à chaque changement de statut → via Supabase Edge Function + un service d'envoi transactionnel (ex. Resend, Brevo) — compte à créer par Badra, clé API stockée en secret Supabase, jamais dans le code
- SMS de confirmation au client avec la référence → nécessite un fournisseur SMS (à choisir : Twilio, ou un agrégateur local CI) — décision et abonnement à prendre par Badra avant implémentation

## Tableau de bord admin — KPI attendus
- Compteurs : nouvelles / en cours / résolues / en retard, délai moyen de résolution
- Graphiques : évolution mensuelle, répartition par agence, par type, par gestionnaire, délai moyen
- Filtres et recherche sur la liste des réclamations
- Export Excel (réutiliser le pattern `xlsx-js-style` déjà utilisé sur Coris-Point-Hebdo)

## Fiche client unifiée (bonus, phase ultérieure)
Recherche par numéro de compte → affichage des réclamations liées à ce client. **Ne dépend pas d'un accès au core banking** : se base uniquement sur les réclamations déjà enregistrées dans cette base, pas une intégration avec Amplitude.

## Ordre de construction recommandé
1. Formulaire client + table `reclamations` + workflow de statuts + tableau de bord staff (authentification, liste, filtres)
2. Pièces jointes (Supabase Storage) + commentaires + historique détaillé
3. KPI avancés + export Excel + affichage SLA visuel (orange/rouge)
4. QR Code + Edge Function notifications email
5. SMS + relances automatiques planifiées (pg_cron)

## Style de travail attendu
- Fournir le fichier `index.html` complet à chaque livraison, jamais des fragments
- Vérifier la syntaxe JS avant de livrer
- Toute création de table/colonne Supabase : fournir le script SQL exact à exécuter manuellement (pas d'accès réseau direct à Supabase depuis Claude Code)
- Langue de travail : français
- Corrections ciblées, pas de refonte complète sauf demande explicite

## État d'avancement
- **Étape 1 livrée** (voir `schema_step1.sql` + `index.html`) : formulaire public de dépôt, génération de référence `PL-YYYYMMDD-00001` et échéance SLA via trigger Postgres, tableau de bord staff (connexion Supabase Auth, liste, filtres, KPI simples, avancement du workflow avec historique JSONB).
- **Étape 3 livrée** (KPI avancés) : délai moyen de résolution (calculé à partir de la première entrée `historique` vers `resolu`/`clos`), 4 graphiques Chart.js (évolution mensuelle, répartition par nature/agence/gestionnaire, avec regroupement "Autres" au-delà de 8 catégories), export Excel (`xlsx-js-style`, respecte les filtres actifs de la liste). Étape 2 (pièces jointes/commentaires) volontairement passée pour l'instant, à faire en dernier — décision explicite de l'utilisateur.
- **Assignation par liste déroulante + notification email** : le champ "Assigné à" de la modale staff est maintenant une liste déroulante peuplée depuis `profiles` (actifs uniquement, voir `schema_assignation.sql` pour la policy RLS requise). Quand l'assignation change vers une personne ayant un email connu, `index.html` envoie l'email **directement côté client via EmailJS** (`EMAILJS_PUBLIC_KEY` / `EMAILJS_SERVICE_ID` / `EMAILJS_TEMPLATE_ASSIGNATION`, template "Réclamation assignée" créé sur le compte EmailJS déjà utilisé par CréditTrack, variables : `to_email`, `to_name`, `reference`, `agence`, `type_plainte`, `description`).
  - ⚠️ **Historique** : la première version utilisait Resend + une Edge Function Supabase (`supabase/functions/notifier-assignation`). Ça a échoué en prod : sans domaine vérifié sur Resend, l'envoi n'est autorisé qu'à l'adresse du compte Resend lui-même (erreur 403 `validation_error` vers tout autre destinataire). Comme la vérification de domaine `coris-mesofinance.com` nécessite un accès DNS que l'utilisateur n'a pas, on est passé sur EmailJS (déjà utilisé pour CréditTrack, envoi 100% client-side, pas de restriction de domaine). L'Edge Function et le secret `RESEND_API_KEY` ne sont plus utilisés — à supprimer manuellement sur Supabase si besoin de nettoyage (Edge Functions → notifier-assignation → supprimer ; Secrets → RESEND_API_KEY → supprimer).
- **Suggestions & Avis** (extension hors périmètre initial) : le formulaire public a désormais 3 onglets (Réclamation / Suggestion / Avis). Suggestions et Avis sont volontairement simples — pas de workflow de statut ni d'assignation, juste une collecte + une liste consultable côté staff (nouveaux sous-onglets du dashboard). Avis = notation 1-5 étoiles liée à une agence + commentaire optionnel ; KPI note moyenne/nombre d'avis affichés. Tables et policies dans `schema_suggestions_avis.sql` (dépôt direct par anon en INSERT, pas de RPC — pas besoin de renvoyer de donnée générée au client contrairement aux réclamations).
- **QR Code livré** : bouton "📱 QR Code" dans l'en-tête staff, génère côté client (librairie `qrcodejs` via CDN) un QR pointant vers `https://corismesofinance.github.io/Coris-Reclamations/` (URL codée en dur dans `PROD_URL`, à mettre à jour si le dépôt de prod change), avec bouton de téléchargement PNG. Pas de dépendance réseau tierce (génération 100% locale, pas d'appel à une API de QR en ligne).
- **Pas encore fait** : pièces jointes (Storage), commentaires dédiés sur les réclamations, notifications email à la création/changement de statut (seule l'assignation déclenche un email pour l'instant), SMS, relances pg_cron.
- Projet Supabase dédié **créé et configuré** : URL `https://pqsczevlnvdayelkjtmq.supabase.co`, clé anon renseignée dans `index.html` (`SB_URL` / `SB_KEY`), `schema_step1.sql` exécuté, premier compte staff créé (`bcoulibaly@coris-mesofinance.com`, rôle `admin`).
- **Dépôt GitHub officiel : `CorisMesofinance/Coris-Reclamations`**, déployé avec succès sur GitHub Pages : https://corismesofinance.github.io/Coris-Reclamations/. Remote git local : `coris`.
- Historique du déploiement : le dépôt initial `abadracoulibaly-max/Coris-Reclamations` (remote `origin`) est resté bloqué en `deployment_queued` sur GitHub Pages malgré plusieurs tentatives (re-run, reset d'environnement, nouveau commit), sans lien avec le code. Un dépôt de secours `abadracoulibaly-max/Coris-Reclamations-App` (remote `app`) a été créé pour isoler le problème mais souffrait du même blocage — ce qui a mené à tester un compte GitHub totalement différent (`CorisMesofinance`), qui a fonctionné du premier coup. `origin` et `app` peuvent être ignorés/supprimés ; `coris` est le remote de prod à utiliser pour les prochains push.
- ⚠️ Le dépôt `CorisMesofinance/Coris-Reclamations` a lui aussi rencontré un blocage similaire après les 2e/3e push (déploiement resté "in progress" bloquant les suivants avec l'erreur `HttpError: Deployment request failed ... due to in progress deployment`). Résolu en supprimant et recréant l'environnement `github-pages` (Settings → Environments). Si ça se reproduit : vérifier d'abord si un déploiement reste bloqué avant de re-run/re-push.
