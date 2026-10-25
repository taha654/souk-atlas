-- =============================================================================
-- Migration : vraies photos (Pixabay) pour les produits et annonces de démo.
-- 05_seed.sql contient déjà ces chemins pour une installation neuve ;
-- ce script les applique à une base EXISTANTE, sans perdre ses données.
--   docker compose exec -T oracle bash -c 'sqlplus -s "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1" @/opt/souk/database/migrations/2026-10-27_photos_demo.sql'
--
-- Seules les illustrations de démo changent : le motif ne touche jamais une
-- photo envoyée par un utilisateur (/uploads/...). Les SVG restent sur le disque
-- comme image de repli (public/assets/js/photos-repli.js).
--
-- Les vues listées ci-dessous gardent leur illustration SVG : Pixabay n'avait
-- pas de photo juste (sans marque ni logo). Même liste que dans 05_seed.sql ;
-- elle correspond aux vues absentes de public/images/demo/credits.json.
-- Le script peut être relancé : une ligne déjà en WebP ne correspond plus au motif.
-- =============================================================================
WHENEVER SQLERROR EXIT FAILURE
UPDATE produit_photo
   SET chemin = REGEXP_REPLACE(chemin, '^/assets/img/produits/(produit-[0-9]+-[0-9]+)\.svg$', '/images/demo/\1.webp')
 WHERE REGEXP_LIKE(chemin, '^/assets/img/produits/produit-[0-9]+-[0-9]+\.svg$')
   AND REGEXP_SUBSTR(chemin, 'produit-[0-9]+-[0-9]+') NOT IN (
       'produit-1-1', 'produit-1-2', 'produit-2-1', 'produit-4-1', 'produit-4-2', 'produit-10-1',
       'produit-10-2', 'produit-11-1', 'produit-11-2', 'produit-11-3', 'produit-13-1', 'produit-13-2',
       'produit-14-2', 'produit-20-2', 'produit-22-2', 'produit-25-2', 'produit-27-1', 'produit-28-1',
       'produit-28-2', 'produit-31-2', 'produit-37-1', 'produit-37-2', 'produit-38-1', 'produit-38-2',
       'produit-38-3', 'produit-39-1', 'produit-43-1', 'produit-44-3', 'produit-46-1', 'produit-46-2',
       'produit-47-3', 'produit-54-1');
UPDATE annonce_photo
   SET chemin = REGEXP_REPLACE(chemin, '^/assets/img/annonces/(annonce-[0-9]+)\.svg$', '/images/demo/\1.webp')
 WHERE REGEXP_LIKE(chemin, '^/assets/img/annonces/annonce-[0-9]+\.svg$')
   AND REGEXP_SUBSTR(chemin, 'annonce-[0-9]+') NOT IN (
       'annonce-3', 'annonce-4', 'annonce-16', 'annonce-25', 'annonce-31', 'annonce-32', 'annonce-36',
       'annonce-38');
COMMIT;
EXIT
