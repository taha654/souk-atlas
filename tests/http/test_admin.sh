#!/bin/bash
# =============================================================================
# Tests HTTP de l'étape 7 : espace administrateur.
#   ./tests/http/test_admin.sh
# Critère : « L'admin traite un signalement de bout en bout ».
# Comptes, annonces, catégories et promotions de test supprimés à la fin.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
source tests/http/outils.sh

nettoyer() {
    set +e
    sql "DELETE FROM promotion WHERE libelle LIKE 'Test HTTP%';
DELETE FROM categorie WHERE nom LIKE 'Test HTTP%' AND id_parent IS NOT NULL;
DELETE FROM categorie WHERE nom LIKE 'Test HTTP%';
UPDATE avis SET statut = 'PUBLIE' WHERE id = ${AVIS:-0};
COMMIT;" > /dev/null
    supprimer_comptes_test
    rm -rf "$TMP"
}
supprimer_comptes_test
trap nettoyer EXIT

ADM="$TMP/admin"; A="$TMP/auteur"; B="$TMP/b"; C="$TMP/c"; V="$TMP/vendeur"; Y="$TMP/youssef"
for j in "$ADM" "$A" "$B" "$C" "$V" "$Y"; do : > "$j"; done
connecter "$ADM" admin@exemple.ma > /dev/null
connecter "$Y" youssef.benali@exemple.ma > /dev/null
inscrire "$A" test-adm-auteur@exemple.ma > /dev/null
inscrire "$B" test-adm-b@exemple.ma > /dev/null
inscrire "$C" test-adm-c@exemple.ma > /dev/null
inscrire "$V" test-adm-vendeur@exemple.ma VENDEUR > /dev/null
ID_ADMIN=$(sql "SELECT id FROM utilisateur WHERE email = 'admin@exemple.ma';")

echo "--- Accès réservé à l'admin"
for u in /admin /admin/signalements /admin/moderation /admin/boutiques /admin/utilisateurs /admin/categories /admin/promotions /admin/journal; do
    verifier "client : $u → 403" 403 "$(code "$B" "$u")"
done
verifier "vendeur : /admin/boutiques → 403" 403 "$(code "$Y" /admin/boutiques)"
verifier "vendeur : POST traiter un signalement → 403" 403 "$(poster "$Y" /admin/signalements/1/traiter decision=APPROUVER)"
verifier "admin : tableau de bord" 200 "$(code "$ADM" /admin)"

echo "--- Signalement traité de bout en bout"
# Annonce d'apparence normale (le moteur C++ la laisse passer) : ce sont des
# utilisateurs qui la signalent, et l'admin qui tranche
poster "$A" /annonces 'titre=iPhone 13 à vendre test' 'description=Bon état, remise en main propre.' prix=1500 ville=Rabat id_categorie=3 > /dev/null
ANN=$(location | sed 's|.*/mes-annonces/||')
poster "$B" "/annonce/$ANN/signaler" motif=ARNAQUE 'commentaire=Prix beaucoup trop bas' > /dev/null
poster "$C" "/annonce/$ANN/signaler" motif=ARNAQUE > /dev/null
LISTE=$(page "$ADM" /admin/signalements)
verifier_contient "visible dans la liste des signalements ouverts" "iPhone 13 à vendre test" "$LISTE"
SIG=$(grep -o "href=\"/admin/signalements/[0-9]*\">iPhone 13 à vendre test" <<< "$LISTE" | grep -o '[0-9]\+' | head -1)
verifier "regroupés : 2 signalements sur une ligne" 1 "$(grep -c "iPhone 13 à vendre test</a></td>" <<< "$LISTE")"
DETAIL=$(page "$ADM" "/admin/signalements/$SIG")
verifier_contient "détail : les deux auteurs" "Prix beaucoup trop bas" "$DETAIL"
verifier "traitement : 303" 303 "$(poster "$ADM" "/admin/signalements/$SIG/traiter" decision=APPROUVER)"
verifier "annonce retirée (REFUSEE)" REFUSEE "$(sql "SELECT statut FROM annonce WHERE id = $ANN;")"
verifier "les 2 signalements approuvés, modérateur = admin" "2" \
    "$(sql "SELECT COUNT(*) FROM signalement WHERE id_annonce = $ANN AND statut = 'APPROUVE' AND id_moderateur = $ID_ADMIN;")"
verifier "annonce invisible du public" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/annonce/$ANN")"
verifier_contient "l'auteur voit le motif" "Retirée après signalement (ARNAQUE)" "$(page "$A" "/annonce/$ANN")"
poster "$ADM" "/admin/signalements/$SIG/traiter" decision=REJETER > /dev/null
verifier_contient "2e traitement refusé" "déjà été traité" "$(page "$ADM" /admin/signalements)"

echo "--- Signalement rejeté : l'annonce reste"
poster "$A" /annonces 'titre=Table basse en bois test' 'description=Table basse, quelques rayures.' prix=300 ville=Fès id_categorie=13 > /dev/null
ANN2=$(location | sed 's|.*/mes-annonces/||')
poster "$B" "/annonce/$ANN2/signaler" motif=DOUBLON > /dev/null
SIG2=$(sql "SELECT id FROM signalement WHERE id_annonce = $ANN2;")
poster "$ADM" "/admin/signalements/$SIG2/traiter" decision=REJETER > /dev/null
verifier "rejeté : annonce toujours en ligne" "EN_LIGNE REJETE" \
    "$(sql "SELECT statut FROM annonce WHERE id = $ANN2;") $(sql "SELECT statut FROM signalement WHERE id = $SIG2;")"

echo "--- Annonces à vérifier (score de risque)"
sql "UPDATE annonce SET statut = 'EN_MODERATION', score_risque = 85 WHERE id = $ANN2;
COMMIT;" > /dev/null
verifier_contient "listée avec son score" "Risque 85/100" "$(page "$ADM" /admin/moderation)"
poster "$ADM" "/admin/annonces/$ANN2/moderer" decision=REFUSER motif= > /dev/null
verifier_contient "refus sans motif : refusé (PKG_ANNONCE)" "Un refus doit être motivé" "$(page "$ADM" /admin/moderation)"
poster "$ADM" "/admin/annonces/$ANN2/moderer" decision=APPROUVER > /dev/null
verifier "approuvée : en ligne" EN_LIGNE "$(sql "SELECT statut FROM annonce WHERE id = $ANN2;")"

echo "--- Avis"
AVIS=$(sql "SELECT MIN(id) FROM avis WHERE statut = 'PUBLIE' AND id_produit = 1;")
NB=$(sql "SELECT nb_avis FROM produit WHERE id = 1;")
poster "$ADM" "/admin/avis/$AVIS/statut" statut=MASQUE > /dev/null
verifier "avis masqué : nb_avis du produit - 1 (trigger)" "$((NB - 1))" "$(sql "SELECT nb_avis FROM produit WHERE id = 1;")"
poster "$ADM" "/admin/avis/$AVIS/statut" statut=PUBLIE > /dev/null
verifier "avis republié" "$NB" "$(sql "SELECT nb_avis FROM produit WHERE id = 1;")"

echo "--- Validation des vendeurs"
poster "$V" /vendeur/boutique 'nom=Boutique Test Admin' ville=Tanger > /dev/null
BOUT=$(sql "SELECT b.id FROM boutique b JOIN utilisateur u ON u.id = b.id_vendeur WHERE u.email = 'test-adm-vendeur@exemple.ma';")
verifier_contient "boutique en attente listée" "Boutique Test Admin" "$(page "$ADM" '/admin/boutiques?statut=EN_ATTENTE')"
poster "$ADM" "/admin/boutiques/$BOUT/statut" statut=VALIDEE > /dev/null
verifier "boutique validée" VALIDEE "$(sql "SELECT statut FROM boutique WHERE id = $BOUT;")"
poster "$V" /vendeur/produits 'nom=Article Test Admin' prix_ht=100 id_categorie=13 stock=5 > /dev/null
verifier "produit visible au catalogue" 1 "$(curl -s "$BASE/api/produits?q=Article+Test+Admin" | json "d['total']")"
poster "$ADM" "/admin/boutiques/$BOUT/statut" statut=SUSPENDUE > /dev/null
verifier "boutique suspendue : produit retiré du catalogue" 0 "$(curl -s "$BASE/api/produits?q=Article+Test+Admin" | json "d['total']")"

echo "--- Catégories"
poster "$ADM" /admin/categories 'nom=Test HTTP Musique' id_parent= > /dev/null
CAT=$(sql "SELECT id FROM categorie WHERE nom = 'Test HTTP Musique';")
verifier "catégorie racine créée" 1 "$(grep -c '^[0-9]\+$' <<< "$CAT")"
poster "$ADM" /admin/categories 'nom=Test HTTP Guitares' "id_parent=$CAT" > /dev/null
verifier "sous-catégorie : chemin" "TestHTTPMusique>TestHTTPGuitares" \
    "$(sql "SELECT pkg_catalogue.chemin_categorie(id) FROM categorie WHERE nom = 'Test HTTP Guitares';")"
poster "$ADM" "/admin/categories/$CAT/supprimer" > /dev/null
verifier_contient "parent non vide : suppression refusée" "1 sous-catégorie(s)" "$(page "$ADM" /admin/categories)"
poster "$ADM" /admin/categories/3/supprimer > /dev/null
verifier_contient "Smartphones (produits) : suppression refusée" "produit(s)" "$(page "$ADM" /admin/categories)"
poster "$ADM" "/admin/categories/$CAT" 'nom=Test HTTP Instruments' > /dev/null
verifier "renommée" "TestHTTPInstruments" "$(sql "SELECT nom FROM categorie WHERE id = $CAT;")"

echo "--- Promotions"
P50=$(curl -s "$BASE/api/produits?q=tapis+de+yoga" | json "d['produits'][0]['prix_courant_ttc']")
poster "$ADM" /admin/promotions 'libelle=Test HTTP Sport' pourcentage=15 cible=categorie:22 "debut=$(date +%F)" "fin=$(date -d '+3 days' +%F)" > /dev/null
verifier "promotion appliquée au catalogue (-15 %)" 15.0 "$(curl -s "$BASE/api/produits?q=tapis+de+yoga" | json "float(d['produits'][0]['pourcentage_promo'])")"
PROMO=$(sql "SELECT id FROM promotion WHERE libelle = 'Test HTTP Sport';")
poster "$ADM" "/admin/promotions/$PROMO/desactiver" > /dev/null
verifier "promotion arrêtée : prix d'origine" "$P50" "$(curl -s "$BASE/api/produits?q=tapis+de+yoga" | json "d['produits'][0]['prix_courant_ttc']")"
poster "$ADM" /admin/promotions 'libelle=Test HTTP 95' pourcentage=95 cible=categorie:22 "debut=$(date +%F)" "fin=$(date -d '+3 days' +%F)" > /dev/null
verifier_contient "95 % refusé (PKG_CATALOGUE)" "entre 0 (exclu) et 90" "$(page "$ADM" /admin/promotions)"

echo "--- Utilisateurs et journal d'audit"
IDB=$(sql "SELECT id FROM utilisateur WHERE email = 'test-adm-b@exemple.ma';")
poster "$ADM" "/admin/utilisateurs/$IDB" action=role:VENDEUR > /dev/null
verifier "rôle changé : le client devient vendeur" 200 "$(code "$B" /vendeur)"
verifier_contient "journal : auteur = l'administrateur" "Administrateur Souk Atlas (ADMIN)" "$(page "$ADM" '/admin/journal?table=UTILISATEUR')"
poster "$ADM" "/admin/utilisateurs/$IDB" action=desactiver > /dev/null
verifier "compte désactivé : déconnecté immédiatement" 303 "$(code "$B" /compte)"
poster "$ADM" "/admin/utilisateurs/$ID_ADMIN" action=desactiver > /dev/null
verifier_contient "l'admin ne peut pas se désactiver lui-même" "votre propre compte" "$(page "$ADM" /admin/utilisateurs)"
verifier "… et reste actif" ACTIF "$(sql "SELECT statut FROM utilisateur WHERE id = $ID_ADMIN;")"
poster "$ADM" "/admin/utilisateurs/$IDB" action=role:SUPERADMIN > /dev/null
verifier_contient "action inconnue refusée" "Action inconnue" "$(page "$ADM" /admin/utilisateurs)"

echo "--- Statistiques globales"
verifier "API : classement des boutiques (RANK)" 1 "$(page "$ADM" '/api/admin/statistiques?jours=365' | json "d['par_vendeur'][0]['rang']")"
verifier "parts de CA : 100 %" True "$(page "$ADM" '/api/admin/statistiques?jours=365' | json "abs(sum(v['part_pct'] for v in d['par_vendeur']) - 100) <= 0.5")"

bilan ADMIN
