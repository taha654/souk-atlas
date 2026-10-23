#!/bin/bash
# =============================================================================
# Tests HTTP de l'étape 5 : espace vendeur (boutique, produits, stock, photos,
# commandes reçues, statistiques).
#   ./tests/http/test_vendeur.sh
# Critère : « Un vendeur gère son catalogue et voit ses ventes en graphique ».
# Le vendeur et le client de test, leur boutique, leurs produits, leurs photos et
# leurs commandes sont supprimés à la fin.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
source tests/http/outils.sh

nettoyer() {
    supprimer_comptes_test   # données ET fichiers des photos (tests/http/outils.sh)
    rm -rf "$TMP"
}
supprimer_comptes_test
trap nettoyer EXIT

V="$TMP/vendeur"; C="$TMP/client"; Y="$TMP/youssef"; : > "$V"; : > "$C"; : > "$Y"
# Images de test : une vraie PNG 200 x 150, un script déguisé, un fichier trop lourd
python3 - "$TMP" <<'PY'
import struct, sys, zlib
dossier = sys.argv[1]
def png(largeur, hauteur):
    ligne = b'\x00' + b'\x1f\x3a\x93' * largeur
    brut = zlib.compress(ligne * hauteur)
    bloc = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    return b'\x89PNG\r\n\x1a\n' + bloc(b'IHDR', struct.pack('>IIBBBBB', largeur, hauteur, 8, 2, 0, 0, 0)) \
        + bloc(b'IDAT', brut) + bloc(b'IEND', b'')
open(f'{dossier}/photo.png', 'wb').write(png(200, 150))
open(f'{dossier}/script.png', 'wb').write(b'<?php system($_GET["c"]); ?>')
open(f'{dossier}/lourde.png', 'wb').write(png(200, 150) + b'\x00' * (5 * 1024 * 1024 + 500_000))
PY

echo "--- Création de la boutique"
verifier "inscription vendeur → /vendeur" "303 /vendeur" "$(inscrire "$V" test-vend@exemple.ma VENDEUR) $(location)"
verifier_contient "sans boutique : formulaire de création" "Ouvrir ma boutique" "$(page "$V" /vendeur)"
verifier "sans boutique : /vendeur/produits → 404" 404 "$(code "$V" /vendeur/produits)"
verifier "nom trop court : 422" 422 "$(poster "$V" /vendeur/boutique nom=AB ville=Rabat)"
verifier "nom déjà pris (Maison Zellige) : 422" 422 "$(poster "$V" /vendeur/boutique 'nom=Maison Zellige' ville=Rabat)"
verifier "création : 303" "303 /vendeur" "$(poster "$V" /vendeur/boutique 'nom=Boutique Test HTTP' ville=Rabat 'description=Pour les tests') $(location)"
verifier "boutique créée EN_ATTENTE" EN_ATTENTE "$(sql "SELECT b.statut FROM boutique b JOIN utilisateur u ON u.id = b.id_vendeur WHERE u.email = 'test-vend@exemple.ma';")"

echo "--- Accès réservé aux vendeurs"
inscrire "$C" test-vend-client@exemple.ma > /dev/null
for u in /vendeur /vendeur/produits /vendeur/commandes /vendeur/boutique; do
    verifier "client : GET $u → 403" 403 "$(code "$C" "$u")"
done
verifier "client : POST /vendeur/produits → 403" 403 "$(poster "$C" /vendeur/produits nom=Pirate prix_ht=1 id_categorie=3 stock=1)"
verifier "client : API statistiques → 403 (JSON)" "403 Accès refusé" \
    "$(code "$C" /api/vendeur/statistiques) $(page "$C" /api/vendeur/statistiques | json "d['erreur']")"
verifier "visiteur : /vendeur → connexion" 303 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/vendeur")"

echo "--- Produits"
verifier "prix négatif : 422" 422 "$(poster "$V" /vendeur/produits 'nom=Lampe test' prix_ht=-1 id_categorie=13 stock=10)"
verifier_contient "message d'erreur du prix" "Prix HT invalide" "$(cat "$TMP/corps")"
verifier "création : 303" 303 "$(poster "$V" /vendeur/produits 'nom=Lampe <img src=x onerror=alert(1)>' 'prix_ht=100,00' id_categorie=13 stock=10 'description=Lampe de test')"
P=$(location | sed 's|.*/vendeur/produits/||')
verifier "redirection vers la fiche du produit" 1 "$(grep -c '^[0-9]\+$' <<< "$P")"
verifier "boutique EN_ATTENTE : produit invisible du public" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/produit/$P")"
sql "UPDATE boutique SET statut = 'VALIDEE' WHERE id_vendeur = (SELECT id FROM utilisateur WHERE email = 'test-vend@exemple.ma');
COMMIT;" > /dev/null   # validation par l'admin (étape 7)
verifier "boutique validée : produit visible" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/produit/$P")"
verifier_contient "nom piégé échappé dans la liste du vendeur" "Lampe &lt;img src=x onerror=alert(1)&gt;" "$(page "$V" /vendeur/produits)"
verifier "prix TTC public = 120,00 MAD" 1 "$(curl -s "$BASE/produit/$P" | grep -c '120,00.MAD <small>TTC')"

poster "$V" "/vendeur/produits/$P" 'nom=Lampe test' 'prix_ht=150' id_categorie=13 statut=ACTIF 'description=Lampe de test' > /dev/null
verifier "modification du prix : historique (trigger)" "100->150" \
    "$(sql "SELECT ancien_prix_ht || '->' || nouveau_prix_ht FROM historique_prix WHERE id_produit = $P;")"
verifier_contient "historique affiché au vendeur" "Historique des prix HT" "$(page "$V" "/vendeur/produits/$P")"

echo "--- Stock"
poster "$V" "/vendeur/produits/$P/stock" delta=5 > /dev/null
verifier "+5 : stock 15" 15 "$(sql "SELECT stock FROM produit WHERE id = $P;")"
poster "$V" "/vendeur/produits/$P/stock" delta=-100 > /dev/null
verifier_contient "-100 refusé avec un message" "Stock insuffisant" "$(page "$V" "/vendeur/produits/$P")"
verifier "stock inchangé" 15 "$(sql "SELECT stock FROM produit WHERE id = $P;")"

echo "--- Photos"
verifier "photo PNG valide : 303" 303 "$(envoyer_fichier "$V" "/vendeur/produits/$P/photos" "$TMP/photo.png")"
CHEMIN=$(sql "SELECT MAX(chemin) FROM produit_photo WHERE id_produit = $P;")
verifier "renommée au hasard (32 caractères hexadécimaux)" 1 "$(grep -c '^/uploads/produits/[0-9a-f]\{32\}\.png$' <<< "$CHEMIN")"
verifier "fichier présent sur le disque" 1 "$( [[ -f "public$CHEMIN" ]] && echo 1 || echo 0)"
verifier "fichier appartenant à l'utilisateur de la machine" "$(id -u)" "$(stat -c %u "public$CHEMIN" 2>/dev/null)"
verifier "servie en image/png" "200 image/png" "$(curl -s -o /dev/null -w '%{http_code} %{content_type}' "$BASE$CHEMIN")"
envoyer_fichier "$V" "/vendeur/produits/$P/photos" "$TMP/script.png" > /dev/null
verifier_contient "script PHP déguisé en PNG refusé" "Format refusé" "$(page "$V" "/vendeur/produits/$P")"
envoyer_fichier "$V" "/vendeur/produits/$P/photos" "$TMP/photo.png" "piege.php" "application/x-php" > /dev/null
verifier "vraie image nommée .php : enregistrée en .png" 1 \
    "$(sql "SELECT COUNT(*) FROM produit_photo WHERE id_produit = $P AND chemin LIKE '%.png';" | grep -c '^2$')"
envoyer_fichier "$V" "/vendeur/produits/$P/photos" "$TMP/lourde.png" > /dev/null
verifier_contient "photo de plus de 5 Mo refusée" "Photo trop lourde" "$(page "$V" "/vendeur/produits/$P")"
for i in 3 4 5 6; do envoyer_fichier "$V" "/vendeur/produits/$P/photos" "$TMP/photo.png" > /dev/null; done
envoyer_fichier "$V" "/vendeur/produits/$P/photos" "$TMP/photo.png" > /dev/null
verifier_contient "7e photo refusée (règle en base)" "au plus 6 photos" "$(page "$V" "/vendeur/produits/$P")"
verifier "exactement 6 photos" 6 "$(sql "SELECT COUNT(*) FROM produit_photo WHERE id_produit = $P;")"
verifier "aucun fichier orphelin (6 fichiers pour 6 photos)" 6 \
    "$(for c in $(sql "SELECT chemin FROM produit_photo WHERE id_produit = $P;" | sed 's|/uploads|\n/uploads|g'); do [[ -f public$c ]] && echo x; done | wc -l)"
ID_PHOTO=$(sql "SELECT MIN(id) FROM produit_photo WHERE id_produit = $P;")
CHEMIN=$(sql "SELECT chemin FROM produit_photo WHERE id = $ID_PHOTO;")
poster "$V" "/vendeur/produits/$P/photos/$ID_PHOTO/supprimer" > /dev/null
verifier "photo supprimée en base" 0 "$(sql "SELECT COUNT(*) FROM produit_photo WHERE id = $ID_PHOTO;")"
verifier "… et son fichier effacé" 0 "$( [[ -f "public$CHEMIN" ]] && echo 1 || echo 0)"

echo "--- Un vendeur ne touche qu'à sa boutique"
connecter "$Y" youssef.benali@exemple.ma > /dev/null
S1=$(sql "SELECT stock FROM produit WHERE id = 1;")
verifier "produit d'un autre vendeur : 404" 404 "$(code "$V" /vendeur/produits/1)"
verifier "stock d'un autre vendeur : 404" 404 "$(poster "$V" /vendeur/produits/1/stock delta=-5)"
verifier "… et le stock n'a pas bougé" "$S1" "$(sql "SELECT stock FROM produit WHERE id = 1;")"
verifier "Youssef ne voit pas le produit de test" 404 "$(code "$Y" "/vendeur/produits/$P")"

echo "--- Commandes reçues"
curl -s -o /dev/null -b "$C" -c "$C" -H "X-CSRF-Token: $(jeton "$C")" --data "operation=ajouter&id_produit=$P&quantite=2" "$BASE/api/panier"
poster "$C" /commande mode=LIVRAISON 'adresse=12 rue des Orangers' ville=Fès 'telephone=0612345678' > /dev/null
NUM=$(sql "SELECT MAX(numero) FROM commande c JOIN utilisateur u ON u.id = c.id_client WHERE u.email = 'test-vend-client@exemple.ma';")
verifier_contient "la commande apparaît chez le vendeur" "$NUM" "$(page "$V" /vendeur/commandes)"
verifier_contient "adresse de livraison visible" "12 rue des Orangers" "$(page "$V" "/vendeur/commandes/$NUM")"
verifier "Youssef : commande d'une autre boutique → 404" 404 "$(code "$Y" "/vendeur/commandes/$NUM")"
verifier "Youssef : changement de statut → 404" 404 "$(poster "$Y" "/vendeur/commandes/$NUM/statut" statut=EXPEDIEE)"
poster "$V" "/vendeur/commandes/$NUM/statut" statut=PAYEE > /dev/null
verifier_contient "PAYEE refusé au vendeur" "EXPEDIEE, LIVREE ou ANNULEE" "$(page "$V" "/vendeur/commandes/$NUM")"
poster "$V" "/vendeur/commandes/$NUM/statut" statut=EXPEDIEE > /dev/null
poster "$V" "/vendeur/commandes/$NUM/statut" statut=LIVREE > /dev/null
verifier "expédiée puis livrée ; paiement encaissé" "LIVREE/ACCEPTE" \
    "$(sql "SELECT c.statut || '/' || p.statut FROM commande c JOIN paiement p ON p.id_commande = c.id WHERE c.numero = '$NUM';")"

echo "--- Statistiques (données des graphiques)"
STATS=$(page "$V" "/api/vendeur/statistiques?jours=30")
verifier "1 commande sur 30 jours" 1 "$(json "d['resume']['nb_commandes']" <<< "$STATS")"
verifier "CA HT = 2 x 150" 300.00 "$(json "'%.2f' % d['resume']['ca_ht']" <<< "$STATS")"
verifier "30 points pour la courbe par jour" 30 "$(json "len(d['par_jour'])" <<< "$STATS")"
verifier "12 mois" 12 "$(json "len(d['par_mois'])" <<< "$STATS")"
verifier "meilleure vente = le produit de test" "2" "$(json "d['meilleures_ventes'][0]['quantite']" <<< "$STATS")"
verifier "période inconnue → 30 jours par défaut" 30 "$(page "$V" '/api/vendeur/statistiques?jours=9999' | json "d['jours']")"

bilan VENDEUR
