-- =============================================================================
-- Souk Atlas : données de démonstration (toutes FICTIVES)
--
-- Mot de passe de tous les comptes : Demo1234!
--   admin@exemple.ma              ADMIN
--   youssef.benali@exemple.ma     VENDEUR (Atlas Électronique)
--   amine.lahlou@exemple.ma       CLIENT
--   … voir la table UTILISATEUR pour les autres.
--
-- Les tables de référence reçoivent des id explicites (plus lisible pour
-- relier produits, boutiques et catégories). À la fin, chaque colonne IDENTITY
-- est recalée après le plus grand id (START WITH LIMIT VALUE).
-- L'historique des ventes (environ 300 commandes sur 12 mois) est généré par
-- un bloc PL/SQL plus bas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Utilisateurs
-- -----------------------------------------------------------------------------
INSERT INTO utilisateur (id, email, mot_de_passe_hash, nom, telephone, ville, role, statut, date_creation)
SELECT id, email, '$2y$10$8IN3Bdq3kuJcHuKZPyMZxuZsoFLW4Ovsn88M2HXoA4K3a6R4CZWYW',
       nom, telephone, ville, role, statut, SYSDATE - anciennete
  FROM (
    SELECT  1 id, 'admin@exemple.ma' email,               'Administrateur Souk Atlas' nom, '0600000001' telephone, 'Rabat' ville,      'ADMIN' role,   'ACTIF' statut, 500 anciennete FROM dual UNION ALL
    SELECT  2, 'youssef.benali@exemple.ma',     'Youssef Benali',       '0600000002', 'Casablanca', 'VENDEUR', 'ACTIF', 480 FROM dual UNION ALL
    SELECT  3, 'salma.elidrissi@exemple.ma',    'Salma El Idrissi',     '0600000003', 'Rabat',      'VENDEUR', 'ACTIF', 470 FROM dual UNION ALL
    SELECT  4, 'karim.tazi@exemple.ma',         'Karim Tazi',           '0600000004', 'Marrakech',  'VENDEUR', 'ACTIF', 460 FROM dual UNION ALL
    SELECT  5, 'nadia.berrada@exemple.ma',      'Nadia Berrada',        '0600000005', 'Fès',        'VENDEUR', 'ACTIF', 450 FROM dual UNION ALL
    SELECT  6, 'omar.chraibi@exemple.ma',       'Omar Chraibi',         '0600000006', 'Tanger',     'VENDEUR', 'ACTIF', 440 FROM dual UNION ALL
    SELECT  7, 'hind.alaoui@exemple.ma',        'Hind Alaoui',          '0600000007', 'Agadir',     'VENDEUR', 'ACTIF', 430 FROM dual UNION ALL
    SELECT  8, 'mehdi.fassi@exemple.ma',        'Mehdi Fassi',          '0600000008', 'Casablanca', 'VENDEUR', 'ACTIF', 420 FROM dual UNION ALL
    SELECT  9, 'rachid.ouazzani@exemple.ma',    'Rachid Ouazzani',      '0600000009', 'Meknès',     'VENDEUR', 'ACTIF', 410 FROM dual UNION ALL
    SELECT 10, 'amine.lahlou@exemple.ma',       'Amine Lahlou',         '0600000010', 'Rabat',      'CLIENT',  'ACTIF', 400 FROM dual UNION ALL
    SELECT 11, 'fatimazahra.bennani@exemple.ma','Fatima Zahra Bennani', '0600000011', 'Casablanca', 'CLIENT',  'ACTIF', 390 FROM dual UNION ALL
    SELECT 12, 'hamza.kettani@exemple.ma',      'Hamza Kettani',        '0600000012', 'Fès',        'CLIENT',  'ACTIF', 380 FROM dual UNION ALL
    SELECT 13, 'imane.sqalli@exemple.ma',       'Imane Sqalli',         '0600000013', 'Marrakech',  'CLIENT',  'ACTIF', 370 FROM dual UNION ALL
    SELECT 14, 'yassine.amrani@exemple.ma',     'Yassine Amrani',       '0600000014', 'Tanger',     'CLIENT',  'ACTIF', 360 FROM dual UNION ALL
    SELECT 15, 'khadija.naciri@exemple.ma',     'Khadija Naciri',       '0600000015', 'Agadir',     'CLIENT',  'ACTIF', 350 FROM dual UNION ALL
    SELECT 16, 'mohammed.filali@exemple.ma',    'Mohammed Filali',      '0600000016', 'Meknès',     'CLIENT',  'ACTIF', 340 FROM dual UNION ALL
    SELECT 17, 'sara.tahiri@exemple.ma',        'Sara Tahiri',          '0600000017', 'Oujda',      'CLIENT',  'ACTIF', 330 FROM dual UNION ALL
    SELECT 18, 'anas.jebli@exemple.ma',         'Anas Jebli',           '0600000018', 'Kénitra',    'CLIENT',  'ACTIF', 320 FROM dual UNION ALL
    SELECT 19, 'leila.mansouri@exemple.ma',     'Leila Mansouri',       '0600000019', 'Tétouan',    'CLIENT',  'ACTIF', 310 FROM dual UNION ALL
    SELECT 20, 'reda.belkadi@exemple.ma',       'Reda Belkadi',         '0600000020', 'El Jadida',  'CLIENT',  'ACTIF', 300 FROM dual UNION ALL
    SELECT 21, 'ghita.zniber@exemple.ma',       'Ghita Zniber',         '0600000021', 'Rabat',      'CLIENT',  'ACTIF', 290 FROM dual UNION ALL
    SELECT 22, 'adil.senhaji@exemple.ma',       'Adil Senhaji',         '0600000022', 'Casablanca', 'CLIENT',  'ACTIF', 280 FROM dual UNION ALL
    SELECT 23, 'meryem.bouzid@exemple.ma',      'Meryem Bouzid',        '0600000023', 'Safi',       'CLIENT',  'ACTIF', 270 FROM dual UNION ALL
    -- Compte créé hier : un des critères du futur score de risque
    SELECT 24, 'zakaria.hilali@exemple.ma',     'Zakaria Hilali',       '0600000024', 'Laâyoune',   'CLIENT',  'ACTIF',   1 FROM dual UNION ALL
    SELECT 25, 'nabil.sahraoui@exemple.ma',     'Nabil Sahraoui',       '0600000025', 'Oujda',      'CLIENT',  'DESACTIVE', 200 FROM dual UNION ALL
    SELECT 26, 'said.rami@exemple.ma',          'Saïd Rami',            '0600000026', 'Settat',     'VENDEUR', 'ACTIF',   3 FROM dual
  );

-- -----------------------------------------------------------------------------
-- Boutiques (la 9 attend la validation de l'admin : ses produits sont invisibles)
-- -----------------------------------------------------------------------------
INSERT INTO boutique (id, id_vendeur, nom, description, ville, statut, date_creation)
SELECT 1 id, 2 id_vendeur, 'Atlas Électronique' nom, 'Smartphones, tablettes, TV et accessoires, livrés partout au Maroc.' description, 'Casablanca' ville, 'VALIDEE' statut, SYSDATE - 470 date_creation FROM dual UNION ALL
SELECT 2, 3, 'Maison Zellige', 'Décoration et artisanat marocain, sélectionnés auprès d''artisans de Fès et Rabat.', 'Rabat', 'VALIDEE', SYSDATE - 460 FROM dual UNION ALL
SELECT 3, 4, 'Souk Mode Marrakech', 'Tenues traditionnelles, babouches et maroquinerie.', 'Marrakech', 'VALIDEE', SYSDATE - 450 FROM dual UNION ALL
SELECT 4, 5, 'Argane & Beauté', 'Cosmétiques naturels : argan, savon noir, ghassoul, eau de rose.', 'Fès', 'VALIDEE', SYSDATE - 440 FROM dual UNION ALL
SELECT 5, 6, 'Tanger Sport', 'Fitness, vélos et football.', 'Tanger', 'VALIDEE', SYSDATE - 430 FROM dual UNION ALL
SELECT 6, 7, 'Petits Lutins', 'Puériculture et jouets.', 'Agadir', 'VALIDEE', SYSDATE - 420 FROM dual UNION ALL
SELECT 7, 8, 'Info Pro Maroc', 'Ordinateurs portables, écrans et périphériques.', 'Casablanca', 'VALIDEE', SYSDATE - 410 FROM dual UNION ALL
SELECT 8, 9, 'Cuisine du Riad', 'Ustensiles de cuisine marocaine et petit électroménager.', 'Meknès', 'VALIDEE', SYSDATE - 400 FROM dual UNION ALL
SELECT 9, 26, 'Bazar Settat', 'Articles pour le thé et objets en bois de thuya.', 'Settat', 'EN_ATTENTE', SYSDATE - 2 FROM dual;

-- -----------------------------------------------------------------------------
-- Catégories (arbre partagé entre marketplace et annonces)
-- -----------------------------------------------------------------------------
INSERT INTO categorie (id, nom, id_parent)
SELECT  1 id, 'Électronique' nom, NULL id_parent FROM dual UNION ALL
SELECT  2, 'Téléphones & tablettes', 1 FROM dual UNION ALL
SELECT  3, 'Smartphones', 2 FROM dual UNION ALL
SELECT  4, 'Tablettes', 2 FROM dual UNION ALL
SELECT  5, 'Accessoires téléphone', 2 FROM dual UNION ALL
SELECT  6, 'Informatique', 1 FROM dual UNION ALL
SELECT  7, 'Ordinateurs portables', 6 FROM dual UNION ALL
SELECT  8, 'Périphériques', 6 FROM dual UNION ALL
SELECT  9, 'TV, audio & consoles', 1 FROM dual UNION ALL
SELECT 10, 'Maison & cuisine', NULL FROM dual UNION ALL
SELECT 11, 'Électroménager', 10 FROM dual UNION ALL
SELECT 12, 'Cuisine & art de la table', 10 FROM dual UNION ALL
SELECT 13, 'Décoration & meubles', 10 FROM dual UNION ALL
SELECT 14, 'Tapis & artisanat', 13 FROM dual UNION ALL
SELECT 15, 'Mode', NULL FROM dual UNION ALL
SELECT 16, 'Homme', 15 FROM dual UNION ALL
SELECT 17, 'Femme', 15 FROM dual UNION ALL
SELECT 18, 'Tenues traditionnelles', 15 FROM dual UNION ALL
SELECT 19, 'Beauté & santé', NULL FROM dual UNION ALL
SELECT 20, 'Soins & cosmétiques', 19 FROM dual UNION ALL
SELECT 21, 'Parfums', 19 FROM dual UNION ALL
SELECT 22, 'Sport & loisirs', NULL FROM dual UNION ALL
SELECT 23, 'Fitness', 22 FROM dual UNION ALL
SELECT 24, 'Vélos', 22 FROM dual UNION ALL
SELECT 25, 'Football', 22 FROM dual UNION ALL
SELECT 26, 'Bébé & jouets', NULL FROM dual UNION ALL
SELECT 27, 'Puériculture', 26 FROM dual UNION ALL
SELECT 28, 'Jouets', 26 FROM dual UNION ALL
SELECT 29, 'Véhicules', NULL FROM dual UNION ALL
SELECT 30, 'Voitures', 29 FROM dual UNION ALL
SELECT 31, 'Motos & scooters', 29 FROM dual UNION ALL
SELECT 32, 'Immobilier', NULL FROM dual UNION ALL
SELECT 33, 'Ventes immobilières', 32 FROM dual UNION ALL
SELECT 34, 'Locations', 32 FROM dual;

-- -----------------------------------------------------------------------------
-- Produits (prix HT en dirhams)
-- -----------------------------------------------------------------------------
INSERT INTO produit (id, id_boutique, id_categorie, nom, description, prix_ht, stock, statut, date_creation)
SELECT id, id_boutique, id_categorie, nom, description, prix_ht, stock, statut, SYSDATE - (400 - id * 5)
  FROM (
    -- Atlas Électronique
    SELECT  1 id, 1 id_boutique, 3 id_categorie, 'Smartphone Samsung Galaxy A55 128 Go' nom, 'Écran AMOLED 6,6 pouces, triple capteur photo 50 Mpx, batterie 5000 mAh. Garantie 1 an.' description, 3290 prix_ht, 25 stock, 'ACTIF' statut FROM dual UNION ALL
    SELECT  2, 1, 3, 'Smartphone Xiaomi Redmi Note 13 256 Go', 'Écran 6,67 pouces 120 Hz, appareil photo 108 Mpx, charge rapide 33 W.', 2190, 40, 'ACTIF' FROM dual UNION ALL
    SELECT  3, 1, 3, 'Smartphone Apple iPhone 15 128 Go', 'Puce A16, Dynamic Island, port USB-C. Coloris noir.', 9490, 8, 'ACTIF' FROM dual UNION ALL
    SELECT  4, 1, 3, 'Smartphone Samsung Galaxy S24 256 Go', 'Écran 6,2 pouces, processeur haut de gamme, 7 ans de mises à jour.', 8490, 6, 'ACTIF' FROM dual UNION ALL
    SELECT  5, 1, 4, 'Tablette Samsung Galaxy Tab A9+ 64 Go', 'Écran 11 pouces, quatre haut-parleurs, idéale pour les études.', 1990, 15, 'ACTIF' FROM dual UNION ALL
    SELECT  6, 1, 4, 'Tablette Lenovo Tab M11 128 Go', 'Écran 11 pouces 90 Hz, stylet inclus.', 1790, 12, 'ACTIF' FROM dual UNION ALL
    SELECT  7, 1, 5, 'Coque silicone pour Galaxy A55', 'Coque souple antichoc, intérieur microfibre.', 79, 200, 'ACTIF' FROM dual UNION ALL
    SELECT  8, 1, 5, 'Chargeur rapide USB-C 25 W', 'Chargeur secteur compatible charge rapide, câble fourni.', 149, 150, 'ACTIF' FROM dual UNION ALL
    SELECT  9, 1, 5, 'Écouteurs sans fil Bluetooth', 'Réduction de bruit, 24 h d''autonomie avec le boîtier.', 290, 80, 'ACTIF' FROM dual UNION ALL
    SELECT 10, 1, 5, 'Protection d''écran en verre trempé', 'Verre 9H, pose facile sans bulles.', 49, 300, 'ACTIF' FROM dual UNION ALL
    SELECT 11, 1, 5, 'Batterie externe 20000 mAh', 'Deux ports USB, charge rapide, indicateur de niveau.', 249, 60, 'ACTIF' FROM dual UNION ALL
    SELECT 12, 1, 9, 'Téléviseur LED 55 pouces 4K', 'Smart TV, HDR, Wi-Fi intégré.', 4590, 10, 'ACTIF' FROM dual UNION ALL
    SELECT 13, 1, 9, 'Barre de son 2.1 avec caisson', 'Puissance 300 W, Bluetooth, entrée HDMI ARC.', 1290, 14, 'ACTIF' FROM dual UNION ALL
    SELECT 14, 1, 9, 'Enceinte Bluetooth portable étanche', 'Étanche IP67, 12 h d''autonomie.', 390, 45, 'ACTIF' FROM dual UNION ALL
    -- Info Pro Maroc
    SELECT 15, 7, 7, 'Ordinateur portable Lenovo IdeaPad 15 pouces Core i5', '16 Go de RAM, SSD 512 Go, clavier AZERTY.', 5990, 10, 'ACTIF' FROM dual UNION ALL
    SELECT 16, 7, 7, 'Ordinateur portable HP 14 pouces Ryzen 5', '8 Go de RAM, SSD 512 Go, léger et autonome.', 5490, 9, 'ACTIF' FROM dual UNION ALL
    SELECT 17, 7, 7, 'Ordinateur portable ASUS Vivobook 16 pouces Core i7', '16 Go de RAM, SSD 1 To, écran 16 pouces.', 7990, 5, 'ACTIF' FROM dual UNION ALL
    SELECT 18, 7, 8, 'Souris sans fil ergonomique', 'Capteur 1600 dpi, récepteur USB nano.', 129, 120, 'ACTIF' FROM dual UNION ALL
    SELECT 19, 7, 8, 'Clavier AZERTY rétroéclairé', 'Clavier filaire, touches silencieuses.', 249, 70, 'ACTIF' FROM dual UNION ALL
    SELECT 20, 7, 8, 'Écran 24 pouces Full HD', 'Dalle IPS, 75 Hz, HDMI et VGA.', 1290, 20, 'ACTIF' FROM dual UNION ALL
    SELECT 21, 7, 8, 'Disque SSD externe 1 To', 'USB-C, jusqu''à 1000 Mo/s.', 890, 30, 'ACTIF' FROM dual UNION ALL
    SELECT 22, 7, 8, 'Sacoche pour ordinateur 15,6 pouces', 'Tissu déperlant, compartiment rembourré.', 219, 50, 'ACTIF' FROM dual UNION ALL
    SELECT 23, 7, 8, 'Imprimante jet d''encre multifonction', 'Impression, copie, numérisation, Wi-Fi.', 990, 12, 'ACTIF' FROM dual UNION ALL
    -- Stock volontairement faible : utile pour tester le refus d'une commande
    SELECT 24, 7, 8, 'Clé USB 64 Go', 'USB 3.0, boîtier métal.', 69, 3, 'ACTIF' FROM dual UNION ALL
    -- Maison Zellige
    SELECT 25, 2, 14, 'Tapis berbère fait main 160 x 230 cm', 'Laine naturelle tissée dans le Moyen Atlas, motifs géométriques.', 2490, 6, 'ACTIF' FROM dual UNION ALL
    SELECT 26, 2, 13, 'Lanterne marocaine en laiton ciselé', 'Hauteur 45 cm, verres colorés.', 450, 25, 'ACTIF' FROM dual UNION ALL
    SELECT 27, 2, 13, 'Pouf en cuir brodé', 'Cuir de chèvre brodé main, livré non rembourré.', 390, 30, 'ACTIF' FROM dual UNION ALL
    SELECT 28, 2, 13, 'Miroir encadré en zellige', 'Diamètre 60 cm, zellige de Fès.', 890, 10, 'ACTIF' FROM dual UNION ALL
    SELECT 29, 2, 14, 'Plateau à thé en cuivre gravé', 'Diamètre 50 cm, gravure traditionnelle.', 320, 18, 'ACTIF' FROM dual UNION ALL
    SELECT 30, 2, 13, 'Coussins en kilim (lot de 2)', 'Housses 45 x 45 cm, garnissage inclus.', 260, 40, 'ACTIF' FROM dual UNION ALL
    -- Cuisine du Riad
    SELECT 31, 8, 12, 'Tajine en terre cuite de Safi', 'Diamètre 30 cm, émaillé, compatible feu doux.', 180, 50, 'ACTIF' FROM dual UNION ALL
    SELECT 32, 8, 12, 'Théière marocaine en inox', 'Contenance 1 litre, finition argentée.', 220, 35, 'ACTIF' FROM dual UNION ALL
    SELECT 33, 8, 12, 'Couscoussier en aluminium 8 L', 'Deux étages, poignées isolées.', 340, 20, 'ACTIF' FROM dual UNION ALL
    SELECT 34, 8, 11, 'Robot pâtissier 1200 W', 'Bol inox 5 L, trois accessoires.', 1490, 8, 'ACTIF' FROM dual UNION ALL
    SELECT 35, 8, 11, 'Machine à café expresso', 'Pression 15 bars, buse vapeur.', 1190, 10, 'ACTIF' FROM dual UNION ALL
    SELECT 36, 8, 11, 'Mixeur plongeant 800 W', 'Pied inox, fouet et hachoir fournis.', 349, 25, 'ACTIF' FROM dual UNION ALL
    -- Souk Mode Marrakech
    SELECT 37, 3, 18, 'Djellaba homme en laine', 'Laine fine, coupe traditionnelle, tailles M à XXL.', 790, 15, 'ACTIF' FROM dual UNION ALL
    SELECT 38, 3, 18, 'Caftan brodé main', 'Tissu satiné, broderie au fil doré.', 2290, 5, 'ACTIF' FROM dual UNION ALL
    SELECT 39, 3, 16, 'Babouches en cuir pour homme', 'Cuir véritable, semelle cousue.', 190, 40, 'ACTIF' FROM dual UNION ALL
    SELECT 40, 3, 17, 'Babouches brodées pour femme', 'Broderie fil de soie, pointures 36 à 41.', 210, 40, 'ACTIF' FROM dual UNION ALL
    SELECT 41, 3, 16, 'Chemise en lin pour homme', 'Lin lavé, manches longues.', 290, 30, 'ACTIF' FROM dual UNION ALL
    SELECT 42, 3, 17, 'Sac à main en cuir tressé', 'Cuir tressé à la main, doublure coton.', 590, 20, 'ACTIF' FROM dual UNION ALL
    -- Produit retiré de la vente par son vendeur
    SELECT 43, 3, 18, 'Jabador enfant', 'Ensemble deux pièces pour enfant.', 390, 12, 'INACTIF' FROM dual UNION ALL
    -- Argane & Beauté
    SELECT 44, 4, 20, 'Huile d''argan cosmétique bio 100 ml', 'Pressée à froid, coopérative de la région d''Essaouira.', 120, 100, 'ACTIF' FROM dual UNION ALL
    SELECT 45, 4, 20, 'Savon noir à l''eucalyptus 250 g', 'Savon traditionnel pour le hammam.', 45, 150, 'ACTIF' FROM dual UNION ALL
    SELECT 46, 4, 20, 'Ghassoul en poudre 200 g', 'Argile naturelle de l''Atlas.', 35, 120, 'ACTIF' FROM dual UNION ALL
    SELECT 47, 4, 20, 'Eau de rose 200 ml', 'Eau florale distillée, sans alcool.', 55, 90, 'ACTIF' FROM dual UNION ALL
    SELECT 48, 4, 20, 'Coffret hammam traditionnel', 'Savon noir, ghassoul, gant kessa et huile d''argan.', 290, 25, 'ACTIF' FROM dual UNION ALL
    SELECT 49, 4, 21, 'Parfum au musc blanc 50 ml', 'Eau de parfum aux notes poudrées.', 240, 30, 'ACTIF' FROM dual UNION ALL
    -- Tanger Sport
    SELECT 50, 5, 23, 'Tapis de yoga antidérapant', 'Épaisseur 6 mm, sangle de transport.', 199, 50, 'ACTIF' FROM dual UNION ALL
    SELECT 51, 5, 23, 'Haltères réglables 2 x 10 kg', 'Disques en fonte, barres chromées.', 690, 15, 'ACTIF' FROM dual UNION ALL
    SELECT 52, 5, 24, 'Vélo VTT 27,5 pouces 21 vitesses', 'Cadre aluminium, freins à disque.', 2990, 7, 'ACTIF' FROM dual UNION ALL
    SELECT 53, 5, 25, 'Ballon de football taille 5', 'Ballon cousu, usage terrain synthétique.', 149, 60, 'ACTIF' FROM dual UNION ALL
    SELECT 54, 5, 25, 'Maillot de football rouge et vert', 'Tissu respirant, tailles S à XXL.', 249, 40, 'ACTIF' FROM dual UNION ALL
    SELECT 55, 5, 23, 'Gourde isotherme 750 ml', 'Inox double paroi, 12 h au frais.', 129, 70, 'ACTIF' FROM dual UNION ALL
    -- Petits Lutins
    SELECT 56, 6, 27, 'Poussette compacte pliable', 'Pliage d''une main, dès la naissance.', 1890, 8, 'ACTIF' FROM dual UNION ALL
    SELECT 57, 6, 27, 'Siège auto bébé groupe 0+/1', 'Installation Isofix, de 0 à 18 kg.', 1290, 6, 'ACTIF' FROM dual UNION ALL
    SELECT 58, 6, 28, 'Jeu de construction 500 pièces', 'Briques compatibles, dès 6 ans.', 249, 35, 'ACTIF' FROM dual UNION ALL
    -- Bazar Settat (boutique en attente de validation)
    SELECT 59, 9, 12, 'Lot de 6 verres à thé décorés', 'Verres peints à la main.', 90, 60, 'ACTIF' FROM dual UNION ALL
    SELECT 60, 9, 14, 'Plateau en bois de thuya', 'Bois de thuya d''Essaouira, 40 cm.', 350, 10, 'ACTIF' FROM dual
  );

-- Quelques baisses de prix : le trigger TRG_PRODUIT_HISTORIQUE_PRIX les archive
UPDATE produit SET prix_ht = 8990 WHERE id = 3;
UPDATE produit SET prix_ht = 2490 WHERE id = 2;
UPDATE produit SET prix_ht = 2190 WHERE id = 2;
UPDATE produit SET prix_ht = 5790 WHERE id = 15;
UPDATE historique_prix SET date_changement = SYSDATE - 20 WHERE id_produit = 2 AND nouveau_prix_ht = 2490;

-- Photos : 1 à 3 illustrations SVG par produit. Les fichiers sont générés à
-- partir de ces lignes par tools/generer_illustrations.php (public/assets/img/produits/).
INSERT INTO produit_photo (id_produit, chemin, ordre)
SELECT p.id, '/assets/img/produits/produit-' || p.id || '-' || v.n || '.svg', v.n
  FROM produit p
 CROSS JOIN (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 3) v
 WHERE v.n <= MOD(p.id, 3) + 1;

-- -----------------------------------------------------------------------------
-- Promotions
-- Les colonnes de la 1re ligne portent un alias : sans lui, les deux littéraux 1
-- donneraient deux colonnes nommées "1" et Oracle 19c/21c lèverait ORA-00918
-- (column ambiguously defined). Oracle 23ai, plus tolérant, ne dit rien.
-- -----------------------------------------------------------------------------
INSERT INTO promotion (libelle, pourcentage, date_debut, date_fin, id_produit, id_categorie, actif)
SELECT 'Semaine high-tech' libelle, 10 pourcentage, TRUNC(SYSDATE) - 5 date_debut, TRUNC(SYSDATE) + 10 date_fin, NULL id_produit, 1 id_categorie, 1 actif FROM dual UNION ALL
-- Plus forte que la promo de catégorie : c'est elle qui s'applique au Galaxy A55
SELECT 'Offre Galaxy A55', 15, TRUNC(SYSDATE) - 2, TRUNC(SYSDATE) + 5, 1, NULL, 1 FROM dual UNION ALL
-- Terminée mais encore active : le job JOB_FIN_PROMOTIONS la désactivera
SELECT 'Soldes d''été', 30, TRUNC(SYSDATE) - 90, TRUNC(SYSDATE) - 30, NULL, 15, 1 FROM dual UNION ALL
-- Pas encore commencée
SELECT 'Semaine de la beauté', 20, TRUNC(SYSDATE) + 7, TRUNC(SYSDATE) + 14, NULL, 19, 1 FROM dual;

-- -----------------------------------------------------------------------------
-- Historique des ventes : environ 300 achats sur les 12 derniers mois
-- -----------------------------------------------------------------------------
DECLARE
    -- Collections imbriquées : un "panier type" est une liste d'id de produits
    TYPE t_ids IS TABLE OF NUMBER;
    TYPE t_paniers_types IS TABLE OF t_ids;

    -- Produits souvent achetés ensemble : de quoi nourrir les recommandations
    -- du moteur C++ (étape 8)
    v_paniers_types t_paniers_types := t_paniers_types(
        t_ids(1, 7, 10), t_ids(2, 8, 10), t_ids(3, 9), t_ids(4, 9, 11), t_ids(5, 8),
        t_ids(15, 18, 22), t_ids(16, 18), t_ids(20, 19, 18), t_ids(17, 21),
        t_ids(12, 13), t_ids(26, 27, 30), t_ids(25, 30), t_ids(31, 32), t_ids(33, 31),
        t_ids(37, 39), t_ids(38, 40, 42), t_ids(44, 45, 46), t_ids(48, 47),
        t_ids(50, 55), t_ids(53, 54), t_ids(56, 57), t_ids(58, 14));

    -- Informations produit indexées par id (tableaux associatifs)
    TYPE t_nombres IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_textes  IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    v_prix      t_nombres;
    v_boutique  t_nombres;
    v_nom       t_textes;

    v_quantites       t_nombres;   -- id_produit → quantité, pour l'achat en cours
    v_cmd_boutique    t_nombres;   -- id_boutique → id_commande, pour l'achat en cours
    v_villes          t_textes;

    v_nb_achats  CONSTANT PLS_INTEGER := 300;
    v_date       DATE;
    v_age_jours  NUMBER;
    v_client     PLS_INTEGER;
    v_type       PLS_INTEGER;
    v_id_produit PLS_INTEGER;
    v_id_bout    PLS_INTEGER;
    v_mode       VARCHAR2(10);
    v_statut     VARCHAR2(10);
    v_reference  VARCHAR2(20);
    v_ht         NUMBER;
    v_tva        NUMBER;
    v_id_avis    NUMBER;
    v_nb_avis    PLS_INTEGER := 0;

    TYPE t_commentaires IS TABLE OF VARCHAR2(200);
    v_bons t_commentaires := t_commentaires(
        'Très bon produit, conforme à la description.', 'Livraison rapide, je recommande.',
        'Excellent rapport qualité-prix.', 'Bonne qualité, emballage soigné.',
        'Parfait, rien à redire.', 'Le vendeur a été très réactif.');
    v_moyens t_commentaires := t_commentaires(
        'Correct, sans plus.', 'Bon produit mais livraison un peu longue.');
    v_mauvais t_commentaires := t_commentaires(
        'Déçu, la qualité n''est pas au rendez-vous.', 'Produit arrivé abîmé.');
BEGIN
    -- Graine fixe : les données générées sont identiques à chaque installation
    DBMS_RANDOM.SEED(2026);

    FOR p IN (SELECT id, prix_ht, id_boutique, nom FROM produit WHERE id_boutique <> 9) LOOP
        v_prix(p.id) := p.prix_ht;
        v_boutique(p.id) := p.id_boutique;
        v_nom(p.id) := p.nom;
    END LOOP;
    FOR u IN (SELECT id, ville FROM utilisateur WHERE id BETWEEN 10 AND 23) LOOP
        v_villes(u.id) := u.ville;
    END LOOP;

    FOR n IN 1 .. v_nb_achats LOOP
        -- Dates croissantes, plus serrées vers aujourd'hui (activité en hausse)
        v_age_jours := 365 * (1 - POWER(n / v_nb_achats, 0.75));
        v_date := TRUNC(SYSDATE - v_age_jours) + DBMS_RANDOM.VALUE(9, 22) / 24;
        IF v_date > SYSDATE THEN
            v_date := SYSDATE - 1 / 24;
        END IF;
        v_client := TRUNC(DBMS_RANDOM.VALUE(10, 24));   -- clients 10 à 23

        -- Contenu de l'achat : 70 % un panier type, sinon un produit au hasard
        v_quantites.DELETE;
        IF DBMS_RANDOM.VALUE < 0.7 THEN
            v_type := TRUNC(DBMS_RANDOM.VALUE(1, v_paniers_types.COUNT + 1));
            FOR k IN 1 .. v_paniers_types(v_type).COUNT LOOP
                IF k = 1 OR DBMS_RANDOM.VALUE < 0.75 THEN
                    v_quantites(v_paniers_types(v_type)(k)) := 1;
                END IF;
            END LOOP;
        ELSE
            v_id_produit := TRUNC(DBMS_RANDOM.VALUE(1, 59));
            v_quantites(v_id_produit) := 1;
        END IF;
        IF DBMS_RANDOM.VALUE < 0.2 THEN
            v_quantites(TRUNC(DBMS_RANDOM.VALUE(1, 59))) := 1;
        END IF;

        -- Statut selon l'ancienneté de la commande
        v_mode := CASE WHEN DBMS_RANDOM.VALUE < 0.6 THEN 'CARTE' ELSE 'LIVRAISON' END;
        IF v_age_jours > 10 THEN
            v_statut := CASE WHEN DBMS_RANDOM.VALUE < 0.93 THEN 'LIVREE' ELSE 'ANNULEE' END;
        ELSIF v_age_jours > 3 THEN
            v_statut := CASE WHEN DBMS_RANDOM.VALUE < 0.5 THEN 'LIVREE' ELSE 'EXPEDIEE' END;
        ELSE
            v_statut := CASE WHEN v_mode = 'CARTE' THEN 'PAYEE' ELSE 'EN_ATTENTE' END;
        END IF;

        v_reference := 'ACH-' || TO_CHAR(v_date, 'YYYY') || '-' || LPAD(seq_reference_achat.NEXTVAL, 6, '0');
        v_cmd_boutique.DELETE;

        -- Une commande par boutique, comme PKG_COMMANDE.passer_commande
        v_id_produit := v_quantites.FIRST;
        WHILE v_id_produit IS NOT NULL LOOP
            -- Les petits articles partent parfois par 2 ou 3
            IF v_prix(v_id_produit) < 300 AND DBMS_RANDOM.VALUE < 0.3 THEN
                v_quantites(v_id_produit) := TRUNC(DBMS_RANDOM.VALUE(2, 4));
            END IF;
            v_id_bout := v_boutique(v_id_produit);
            IF NOT v_cmd_boutique.EXISTS(v_id_bout) THEN
                INSERT INTO commande (numero, reference_achat, id_client, id_boutique, statut, mode_paiement,
                                      adresse_livraison, ville_livraison, telephone_livraison, date_commande,
                                      date_paiement, date_expedition, date_livraison, date_annulation)
                VALUES ('CMD-' || TO_CHAR(v_date, 'YYYY') || '-' || LPAD(seq_numero_commande.NEXTVAL, 6, '0'),
                        v_reference, v_client, v_id_bout, v_statut, v_mode,
                        TRUNC(DBMS_RANDOM.VALUE(1, 200)) || ', rue des Orangers', v_villes(v_client),
                        '06000000' || LPAD(v_client, 2, '0'), v_date,
                        CASE WHEN v_mode = 'CARTE' AND v_statut <> 'EN_ATTENTE' THEN v_date
                             WHEN v_statut = 'LIVREE' THEN v_date + 3 END,
                        CASE WHEN v_statut IN ('EXPEDIEE', 'LIVREE') THEN v_date + 1 END,
                        CASE WHEN v_statut = 'LIVREE' THEN v_date + 3 END,
                        CASE WHEN v_statut = 'ANNULEE' THEN v_date + 0.5 END)
                RETURNING id INTO v_cmd_boutique(v_id_bout);
            END IF;
            INSERT INTO commande_ligne (id_commande, id_produit, nom_produit, prix_unitaire_ht, quantite, total_ligne_ht)
            VALUES (v_cmd_boutique(v_id_bout), v_id_produit, v_nom(v_id_produit), v_prix(v_id_produit),
                    v_quantites(v_id_produit), v_prix(v_id_produit) * v_quantites(v_id_produit));
            v_id_produit := v_quantites.NEXT(v_id_produit);
        END LOOP;

        -- Totaux et paiement de chaque commande de l'achat
        v_id_bout := v_cmd_boutique.FIRST;
        WHILE v_id_bout IS NOT NULL LOOP
            SELECT SUM(total_ligne_ht) INTO v_ht FROM commande_ligne WHERE id_commande = v_cmd_boutique(v_id_bout);
            v_tva := ROUND(v_ht * 0.20, 2);
            UPDATE commande SET total_ht = v_ht, tva = v_tva, total_ttc = v_ht + v_tva
             WHERE id = v_cmd_boutique(v_id_bout);
            INSERT INTO paiement (id_commande, mode_paiement, montant, statut, carte_4_derniers, date_paiement)
            VALUES (v_cmd_boutique(v_id_bout), v_mode, v_ht + v_tva,
                    CASE WHEN v_statut = 'ANNULEE' AND v_mode = 'CARTE' THEN 'REMBOURSE'
                         WHEN v_mode = 'CARTE' OR v_statut = 'LIVREE' THEN 'ACCEPTE'
                         ELSE 'EN_ATTENTE' END,
                    CASE WHEN v_mode = 'CARTE' THEN LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 10000)), 4, '0') END,
                    v_date);
            v_id_bout := v_cmd_boutique.NEXT(v_id_bout);
        END LOOP;

        -- Avis sur environ un tiers des produits livrés (surtout de bonnes notes)
        IF v_statut = 'LIVREE' THEN
            v_id_produit := v_quantites.FIRST;
            WHILE v_id_produit IS NOT NULL LOOP
                IF DBMS_RANDOM.VALUE < 0.35 THEN
                    DECLARE
                        v_note NUMBER := CASE WHEN DBMS_RANDOM.VALUE < 0.65 THEN 5
                                              WHEN DBMS_RANDOM.VALUE < 0.7 THEN 4
                                              WHEN DBMS_RANDOM.VALUE < 0.6 THEN 3
                                              ELSE TRUNC(DBMS_RANDOM.VALUE(1, 3)) END;
                        v_commentaire VARCHAR2(200);
                    BEGIN
                        -- Choisi en PL/SQL : une collection locale n'est pas
                        -- utilisable dans un ordre SQL (PLS-00425)
                        IF v_note >= 4 THEN
                            v_commentaire := v_bons(TRUNC(DBMS_RANDOM.VALUE(1, v_bons.COUNT + 1)));
                        ELSIF v_note = 3 THEN
                            v_commentaire := v_moyens(TRUNC(DBMS_RANDOM.VALUE(1, v_moyens.COUNT + 1)));
                        ELSE
                            v_commentaire := v_mauvais(TRUNC(DBMS_RANDOM.VALUE(1, v_mauvais.COUNT + 1)));
                        END IF;
                        INSERT INTO avis (id_produit, id_utilisateur, note, commentaire, date_avis)
                        VALUES (v_id_produit, v_client, v_note, v_commentaire, v_date + 5)
                        RETURNING id INTO v_id_avis;
                        v_nb_avis := v_nb_avis + 1;
                    EXCEPTION
                        -- Ce client a déjà noté ce produit lors d'un achat précédent
                        WHEN DUP_VAL_ON_INDEX THEN NULL;
                    END;
                END IF;
                v_id_produit := v_quantites.NEXT(v_id_produit);
            END LOOP;
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(v_nb_achats || ' achats et ' || v_nb_avis || ' avis générés.');
END;
/

-- -----------------------------------------------------------------------------
-- Petites annonces
-- -----------------------------------------------------------------------------
INSERT INTO annonce (id, id_utilisateur, id_categorie, titre, description, prix, ville, statut,
                     score_risque, motif_refus, date_publication, date_expiration)
SELECT id, id_utilisateur, id_categorie, titre, description, prix, ville, statut,
       score_risque, motif_refus, SYSDATE - age, SYSDATE - age + 30
  FROM (
    SELECT  1 id, 10 id_utilisateur, 3 id_categorie, 'iPhone 12 64 Go très bon état' titre, 'Batterie à 88 %, aucune rayure, vendu avec chargeur et coque.' description, 2800 prix, 'Rabat' ville, 'EN_LIGNE' statut, 12 score_risque, CAST(NULL AS VARCHAR2(500)) motif_refus, 3 age FROM dual UNION ALL
    SELECT  2, 11, 3, 'Samsung Galaxy S21 avec boîte et facture', 'Téléphone en excellent état, débloqué tout opérateur.', 2500, 'Casablanca', 'EN_LIGNE', 10, NULL, 5 FROM dual UNION ALL
    SELECT  3, 12, 30, 'Dacia Logan 2017 diesel 120 000 km', 'Première main, carnet d''entretien à jour, visite technique valide.', 72000, 'Fès', 'EN_LIGNE', 8, NULL, 7 FROM dual UNION ALL
    SELECT  4, 22, 30, 'Peugeot 208 2019 essence', 'Boîte manuelle, climatisation, 65 000 km, dédouanée.', 125000, 'Casablanca', 'EN_LIGNE', 9, NULL, 2 FROM dual UNION ALL
    SELECT  5, 13, 31, 'Scooter 125 cc 2021 peu roulé', 'Seulement 4 000 km, entretien chez le concessionnaire.', 14500, 'Marrakech', 'EN_LIGNE', 15, NULL, 10 FROM dual UNION ALL
    SELECT  6, 21, 33, 'Appartement 85 m² à vendre quartier Agdal', 'Deux chambres, salon, cuisine équipée, 3e étage avec ascenseur.', 1350000, 'Rabat', 'EN_LIGNE', 5, NULL, 12 FROM dual UNION ALL
    SELECT  7, 14, 34, 'Studio meublé à louer près de la plage', 'Loyer mensuel, charges comprises, disponible immédiatement.', 3500, 'Tanger', 'EN_LIGNE', 18, NULL, 4 FROM dual UNION ALL
    SELECT  8, 15, 13, 'Canapé d''angle gris 5 places', 'Tissu déhoussable, acheté il y a un an, à récupérer sur place.', 3200, 'Agadir', 'EN_LIGNE', 6, NULL, 6 FROM dual UNION ALL
    SELECT  9, 16, 11, 'Réfrigérateur combiné 300 L', 'Classe A+, fonctionne parfaitement, cause déménagement.', 1800, 'Meknès', 'EN_LIGNE', 7, NULL, 9 FROM dual UNION ALL
    SELECT 10, 17, 24, 'Vélo de course aluminium taille M', 'Groupe 18 vitesses, pneus neufs.', 2200, 'Oujda', 'EN_LIGNE', 11, NULL, 14 FROM dual UNION ALL
    SELECT 11, 18, 9, 'PlayStation 5 et deux manettes', 'Version avec lecteur, garantie encore 6 mois.', 4200, 'Kénitra', 'EN_LIGNE', 20, NULL, 1 FROM dual UNION ALL
    SELECT 12, 19, 27, 'Poussette trio bon état', 'Nacelle, siège auto et poussette, couleur gris.', 900, 'Tétouan', 'EN_LIGNE', 4, NULL, 16 FROM dual UNION ALL
    SELECT 13, 20, 11, 'Machine à laver 7 kg', 'Hublot, 1200 tours, quelques traces d''usage.', 1500, 'El Jadida', 'EN_LIGNE', 6, NULL, 18 FROM dual UNION ALL
    SELECT 14, 22, 13, 'Table en bois massif et 6 chaises', 'Table 180 cm en noyer, chaises rembourrées.', 4500, 'Casablanca', 'EN_LIGNE', 5, NULL, 20 FROM dual UNION ALL
    SELECT 15, 23, 7, 'MacBook Air M1 2020 8 Go / 256 Go', 'Très peu servi, batterie 95 %, clavier AZERTY.', 6500, 'Safi', 'EN_LIGNE', 22, NULL, 8 FROM dual UNION ALL
    SELECT 16, 13, 18, 'Caftan de mariée porté une fois', 'Taille 38, broderie dorée, avec ceinture.', 3500, 'Marrakech', 'EN_LIGNE', 7, NULL, 11 FROM dual UNION ALL
    SELECT 17, 15, 31, 'Moto trail 250 cc 2018', 'Entretien suivi, pneus récents, papiers en règle.', 28000, 'Agadir', 'EN_LIGNE', 13, NULL, 13 FROM dual UNION ALL
    SELECT 18, 11, 34, 'Appartement 3 chambres à louer centre-ville', 'Loyer mensuel, proche tramway, libre au 1er du mois.', 6000, 'Casablanca', 'EN_LIGNE', 9, NULL, 15 FROM dual UNION ALL
    SELECT 19, 13, 8, 'Écran gamer 27 pouces 144 Hz', 'Dalle IPS, pied réglable, aucun pixel mort.', 1600, 'Marrakech', 'EN_LIGNE', 10, NULL, 17 FROM dual UNION ALL
    SELECT 20, 21, 23, 'Tapis de course pliable', 'Vitesse max 14 km/h, très peu utilisé.', 2500, 'Rabat', 'EN_LIGNE', 8, NULL, 19 FROM dual UNION ALL
    SELECT 21, 23, 28, 'Lot de 3 boîtes de briques de construction', 'Boîtes complètes avec notices.', 600, 'Safi', 'EN_LIGNE', 5, NULL, 21 FROM dual UNION ALL
    SELECT 22, 24, 11, 'Climatiseur split 12000 BTU', 'Réversible chaud / froid, installation non comprise.', 2800, 'Laâyoune', 'EN_LIGNE', 35, NULL, 1 FROM dual UNION ALL
    SELECT 23, 14, 4, 'Tablette iPad 9e génération', '64 Go Wi-Fi, avec étui clavier.', 2300, 'Tanger', 'EN_LIGNE', 14, NULL, 22 FROM dual UNION ALL
    SELECT 24, 16, 13, 'Salon marocain complet 6 mètres', 'Banquettes, tissu brodé, table en bois sculpté.', 5500, 'Meknès', 'EN_LIGNE', 6, NULL, 23 FROM dual UNION ALL
    SELECT 25, 17, 30, 'Renault Clio 4 2016 diesel', 'Climatisation, 140 000 km, deuxième main.', 98000, 'Oujda', 'EN_LIGNE', 9, NULL, 24 FROM dual UNION ALL
    SELECT 26, 22, 33, 'Villa avec jardin à vendre à Bouskoura', 'Quatre chambres, piscine, garage, titre foncier.', 2900000, 'Casablanca', 'EN_LIGNE', 12, NULL, 25 FROM dual UNION ALL
    SELECT 27, 12, 16, 'Babouches neuves pointure 42', 'Cuir jaune traditionnel, jamais portées.', 150, 'Fès', 'EN_LIGNE', 3, NULL, 26 FROM dual UNION ALL
    SELECT 28, 18, 27, 'Lit bébé en bois avec matelas', 'Barreaux réglables sur trois hauteurs.', 700, 'Kénitra', 'EN_LIGNE', 4, NULL, 27 FROM dual UNION ALL
    SELECT 29, 19, 22, 'Guitare acoustique avec housse', 'Idéale pour débuter, cordes changées récemment.', 900, 'Tétouan', 'EN_LIGNE', 5, NULL, 28 FROM dual UNION ALL
    SELECT 30, 20, 5, 'Montre connectée sport', 'Cardiofréquencemètre, GPS, bracelet de rechange.', 450, 'El Jadida', 'EN_LIGNE', 8, NULL, 29 FROM dual UNION ALL
    -- En attente de modération : score de risque élevé
    SELECT 31, 24, 3, 'iPhone 15 Pro Max neuf sous blister à 2000 DH', 'Urgent !!! Prix imbattable, paiement par virement avant envoi.', 2000, 'Casablanca', 'EN_MODERATION', 88, NULL, 0.5 FROM dual UNION ALL
    SELECT 32, 24, 30, 'Voiture récente à prix sacrifié', 'Départ à l''étranger, virement uniquement, pas de visite possible.', 15000, 'Rabat', 'EN_MODERATION', 92, NULL, 0.3 FROM dual UNION ALL
    SELECT 33, 23, 34, 'Appartement de luxe à louer 1500 DH par mois', 'Avance de trois mois demandée avant la visite.', 1500, 'Marrakech', 'EN_MODERATION', 71, NULL, 0.2 FROM dual UNION ALL
    -- Refusées par la modération
    SELECT 34, 14, 21, 'Parfums de grandes marques à -80 %', 'Copies de parfums célèbres, toutes les références.', 100, 'Tanger', 'REFUSEE', 80, 'Contrefaçon', 9 FROM dual UNION ALL
    SELECT 35, 17, 24, 'Vélo de course aluminium taille M (bis)', 'Même vélo que mon autre annonce.', 2200, 'Oujda', 'REFUSEE', 30, 'Annonce en double', 13 FROM dual UNION ALL
    -- Vendues
    SELECT 36, 21, 9, 'Console de jeux portable avec 3 jeux', 'Très bon état, chargeur fourni.', 2100, 'Rabat', 'VENDUE', 10, NULL, 15 FROM dual UNION ALL
    SELECT 37, 12, 13, 'Table basse en cèdre', 'Bois de cèdre de l''Atlas, 100 x 60 cm.', 800, 'Fès', 'VENDUE', 5, NULL, 20 FROM dual UNION ALL
    -- Expirées (plus de 30 jours)
    SELECT 38, 16, 7, 'Ordinateur de bureau complet', 'Unité centrale, écran, clavier et souris.', 1500, 'Meknès', 'EXPIREE', 9, NULL, 50 FROM dual UNION ALL
    SELECT 39, 15, 34, 'Location de vacances à Essaouira en août', 'Maison de 3 chambres à 5 minutes de la plage, prix par nuit.', 700, 'Essaouira', 'EXPIREE', 11, NULL, 70 FROM dual UNION ALL
    SELECT 40, 11, 31, 'Scooter électrique', 'Autonomie 40 km, chargeur fourni.', 4500, 'Casablanca', 'EXPIREE', 7, NULL, 45 FROM dual
  );

-- -----------------------------------------------------------------------------
-- Favoris, messagerie
-- -----------------------------------------------------------------------------
INSERT INTO favori (id_utilisateur, id_annonce)
SELECT 10 id_utilisateur, 3 id_annonce FROM dual UNION ALL SELECT 10, 8 FROM dual UNION ALL SELECT 11, 1 FROM dual UNION ALL
SELECT 14, 6 FROM dual UNION ALL SELECT 21, 11 FROM dual UNION ALL SELECT 13, 26 FROM dual;

DECLARE
    v_conversation NUMBER;
    v_message      NUMBER;
BEGIN
    -- Les conversations passent par le package : c'est aussi un premier test
    pkg_messagerie.ouvrir_conversation(1, 11, v_conversation);   -- iPhone 12 de Amine
    pkg_messagerie.envoyer_message(v_conversation, 11, 'Bonjour, le téléphone est-il toujours disponible ?', v_message);
    pkg_messagerie.envoyer_message(v_conversation, 10, 'Bonjour, oui il est disponible.', v_message);
    pkg_messagerie.envoyer_message(v_conversation, 11, 'Pouvez-vous faire 2600 DH ? Je peux passer demain à Rabat.', v_message);
    pkg_messagerie.marquer_comme_lu(v_conversation, 10, v_message);

    pkg_messagerie.ouvrir_conversation(3, 14, v_conversation);   -- Dacia de Hamza
    pkg_messagerie.envoyer_message(v_conversation, 14, 'Bonjour, la voiture a-t-elle déjà eu un accident ?', v_message);
    pkg_messagerie.envoyer_message(v_conversation, 12, 'Non, jamais. Vous pouvez la faire contrôler si vous voulez.', v_message);

    pkg_messagerie.ouvrir_conversation(8, 10, v_conversation);   -- canapé de Khadija
    pkg_messagerie.envoyer_message(v_conversation, 10, 'Le canapé passe-t-il dans un ascenseur ?', v_message);
END;
/
-- Dates de messages réparties sur les dernières heures
UPDATE message SET date_envoi = SYSTIMESTAMP - NUMTODSINTERVAL(10 - id, 'HOUR');

-- -----------------------------------------------------------------------------
-- Signalements
-- -----------------------------------------------------------------------------
DECLARE
    v_id        NUMBER;
    v_avis_bas  NUMBER;
BEGIN
    pkg_moderation.signaler(10, 'ANNONCE', 31, 'ARNAQUE', 'Prix beaucoup trop bas, demande de virement.', v_id);
    pkg_moderation.signaler(11, 'ANNONCE', 32, 'ARNAQUE', 'Le vendeur refuse toute visite.', v_id);
    pkg_moderation.signaler(12, 'ANNONCE', 32, 'ARNAQUE', NULL, v_id);
    pkg_moderation.signaler(13, 'PRODUIT', 49, 'CONTREFACON', 'Je doute que ce soit un parfum original.', v_id);
    -- Un avis négatif signalé par un autre client
    SELECT MIN(id) INTO v_avis_bas FROM avis WHERE note <= 2;
    IF v_avis_bas IS NOT NULL THEN
        pkg_moderation.signaler(21, 'AVIS', v_avis_bas, 'INAPPROPRIE', 'Avis sans rapport avec le produit.', v_id);
    END IF;
    -- Signalements déjà traités par l'admin
    pkg_moderation.signaler(19, 'ANNONCE', 10, 'DOUBLON', 'Annonce publiée deux fois ?', v_id);
    pkg_moderation.traiter(v_id, 1, 'REJETER');
END;
/

-- -----------------------------------------------------------------------------
-- Paniers en cours (dont un abandonné depuis 45 jours, pour le job de purge)
-- -----------------------------------------------------------------------------
BEGIN
    pkg_panier.ajouter(10, 1, 1);
    pkg_panier.ajouter(10, 7, 2);
    pkg_panier.ajouter(11, 15, 1);
    pkg_panier.ajouter(20, 44, 3);
END;
/
UPDATE panier SET date_maj = SYSDATE - 45 WHERE id_utilisateur = 20;

-- -----------------------------------------------------------------------------
-- Finitions
-- -----------------------------------------------------------------------------
-- Les colonnes IDENTITY reprennent après le plus grand id inséré à la main
ALTER TABLE utilisateur MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE boutique    MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE categorie   MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE produit     MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);
ALTER TABLE annonce     MODIFY id GENERATED BY DEFAULT AS IDENTITY (START WITH LIMIT VALUE);

-- Le chargement a rempli le journal d'audit (chaque INSERT déclenche les
-- triggers) : on le vide pour qu'il ne contienne que la vraie activité du site
DELETE FROM journal_audit;
