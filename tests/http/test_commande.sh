#!/bin/bash
# =============================================================================
# Tests HTTP de l'étape 4 : panier, commande, paiement simulé, suivi, avis.
#   ./tests/http/test_commande.sh
#
# Critère de l'étape : « Une commande de bout en bout fait baisser le stock ;
# un stock insuffisant est refusé proprement ».
#
# Les comptes de test (test-cmd-…@exemple.ma), leurs commandes et le stock
# qu'elles ont consommé sont remis en ordre à la fin (nettoyer_comptes_test.sql).
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."

BASE="${BASE:-http://localhost:8000}"
TMP=$(mktemp -d)
OK=0
ECHECS=0
CARTE='4111 1111 1111 1111'
ANNEE=$(( $(date +%Y) + 2 ))

verifier() {
    if [[ "$2" == "$3" ]]; then OK=$((OK + 1)); echo "OK     $1"
    else ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — attendu : $2, obtenu : $3"; fi
}
verifier_contient() {
    if grep -qF -- "$2" <<< "$3"; then OK=$((OK + 1)); echo "OK     $1"
    else ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — « $2 » introuvable"; fi
}
sql() {   # résultat d'une requête, sans espaces
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' <<< "SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
$1" | tr -d ' \t\r\n'
}
stock() { sql "SELECT stock FROM produit WHERE id = $1;"; }
nb_commandes() { sql "SELECT COUNT(*) FROM commande c JOIN utilisateur u ON u.id = c.id_client WHERE u.email = '$1';"; }

# --- Outils HTTP (un jar = les cookies d'un navigateur) ---
# Jeton CSRF lu dans <meta name="csrf-token"> (présente sur toutes les pages, comme pour le JavaScript)
jeton() { curl -s -b "$1" -c "$1" "$BASE$2" | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | cut -d'"' -f4; }
poster() {   # poster jar url champ=valeur… → code HTTP ; en-têtes dans $TMP/entetes
    local jar="$1" url="$2"; shift 2
    local args=(); for c in "$@"; do args+=(--data-urlencode "$c"); done
    curl -s -o "$TMP/corps" -D "$TMP/entetes" -w '%{http_code}' -b "$jar" -c "$jar" \
        --data-urlencode "_csrf=$(jeton "$jar" /panier)" "${args[@]}" "$BASE$url"
}
api() {      # api jar operation id_produit [quantite] → corps JSON ; code dans $TMP/code
    local jar="$1"; local jt; jt=$(jeton "$jar" /panier)
    curl -s -o "$TMP/json" -w '%{http_code}' -b "$jar" -c "$jar" -H "X-CSRF-Token: $jt" \
        --data "operation=$2&id_produit=$3&quantite=${4:-1}" "$BASE/api/panier" > "$TMP/code"
    cat "$TMP/json"
}
json() { python3 -c "import json, sys; d = json.load(sys.stdin); print($1)"; }
location() { grep -i '^location:' "$TMP/entetes" | tr -d '\r' | cut -d' ' -f2; }
page() { curl -s -b "$1" -c "$1" "$BASE$2"; }
inscrire() {  # inscrire jar email
    poster "$1" /inscription role=CLIENT "nom=Test Commande" "email=$2" \
        mot_de_passe=motdepasse1 confirmation=motdepasse1 > /dev/null
}
commander() { # commander jar [champ=valeur…] : commande par carte (valeurs remplaçables)
    local jar="$1"; shift
    poster "$jar" /commande mode=CARTE "adresse=12 rue des Orangers" ville=Rabat "telephone=06 12 34 56 78" \
        "carte=$CARTE" mois=12 "annee=$ANNEE" cvv=123 "$@"
}

nettoyer() {
    # Ordre important : supprimer d'abord les commandes de test (leur stock est
    # rendu), PUIS remettre les stocks modifiés à la main à leur valeur d'origine.
    # Dans l'autre sens, le stock serait rendu deux fois.
    supprimer_comptes_test
    sql "UPDATE produit SET stock = ${STOCK_ORIGINE[28]} WHERE id = 28;
UPDATE produit SET stock = ${STOCK_ORIGINE[29]} WHERE id = 29;
COMMIT;" > /dev/null
    # Emails simulés adressés aux comptes de test
    grep -l '^To: test-' var/mails/*.eml 2>/dev/null | xargs -r rm -f
    rm -rf "$TMP"
}
# EXIT après le script : sans lui, SQL*Plus attendrait la commande suivante au clavier
supprimer_comptes_test() {
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' > /dev/null <<'SQL'
@/opt/souk/database/tests/nettoyer_comptes_test.sql
EXIT
SQL
}
supprimer_comptes_test   # restes d'une exécution interrompue
# Stocks d'origine des produits que les tests modifient directement en SQL
# (relevés APRÈS le nettoyage initial)
declare -A STOCK_ORIGINE=([28]=$(stock 28) [29]=$(stock 29))
trap nettoyer EXIT

A="$TMP/a"; B="$TMP/b"; : > "$A"; : > "$B"
EMAIL_A=test-cmd-a@exemple.ma
EMAIL_B=test-cmd-b@exemple.ma

# =============================================================================
echo "--- Panier du visiteur, fusion à l'inscription"
verifier "visiteur : ajout au panier (formulaire)" 303 "$(poster "$A" /panier/ajouter id_produit=30 quantite=2 retour=/produit/30)"
verifier "retour sur la fiche produit" /produit/30 "$(location)"
verifier_contient "message flash « Produit ajouté »" "Produit ajouté au panier" "$(page "$A" /produit/30)"
verifier "badge du panier : 2" 2 "$(page "$A" / | grep -o 'id="badge-panier"[^>]*>[0-9]*' | grep -o '[0-9]*$')"
verifier "visiteur : /commande exige la connexion" "303 /connexion?retour=%2Fcommande" \
    "$(curl -s -o /dev/null -D "$TMP/entetes" -w '%{http_code}' -b "$A" "$BASE/commande") $(location)"
inscrire "$A" "$EMAIL_A"
verifier "panier conservé après l'inscription (fusion)" "2" "$(api "$A" ajouter 30 0 > /dev/null; curl -s -b "$A" "$BASE/api/panier" | json "d['nb_articles']")"

echo "--- API du panier"
api "$A" ajouter 44 1 > /dev/null
verifier "API : ajout (jeton CSRF dans l'en-tête)" 200 "$(cat "$TMP/code")"
verifier "API sans jeton CSRF : 403" 403 "$(curl -s -o /dev/null -w '%{http_code}' -b "$A" --data 'operation=ajouter&id_produit=44' "$BASE/api/panier")"
api "$A" modifier 44 3 > /dev/null
verifier "API : quantité modifiée" 5 "$(curl -s -b "$A" "$BASE/api/panier" | json "d['nb_articles']")"
api "$A" ajouter 44 9999 > /dev/null
verifier "API : quantité absurde refusée (422)" 422 "$(cat "$TMP/code")"
verifier "API : produit d'une boutique non validée refusé" 422 "$(api "$A" ajouter 59 1 > /dev/null; cat "$TMP/code")"
TOTAL_PANIER=$(curl -s -b "$A" "$BASE/api/panier" | json "d['total_ttc_texte']")
# Champs "prix" ou "total" ajoutés à la main : le serveur les ignore totalement
curl -s -o /dev/null -b "$A" -c "$A" -H "X-CSRF-Token: $(jeton "$A" /panier)" \
    --data 'operation=ajouter&id_produit=44&quantite=0&prix=0.01&total=1' "$BASE/api/panier"
verifier "prix envoyé par le navigateur ignoré" "$TOTAL_PANIER" "$(curl -s -b "$A" "$BASE/api/panier" | json "d['total_ttc_texte']")"

echo "--- Commande par carte (parcours complet)"
S30=$(stock 30); S44=$(stock 44)
verifier "commande : 303" 303 "$(commander "$A" total_ttc=1 prix=1)"
REF=$(location | sed 's|.*/achat/||')
verifier "redirection vers la confirmation" 1 "$(grep -c '^ACH-[0-9]\{4\}-[0-9]\{6\}$' <<< "$REF")"
verifier "stock du produit 30 diminué de 2" $((S30 - 2)) "$(stock 30)"
verifier "stock du produit 44 diminué de 3" $((S44 - 3)) "$(stock 44)"
verifier "une commande par boutique (2 boutiques)" 2 "$(nb_commandes "$EMAIL_A")"
verifier "montant facturé = total affiché dans le panier (pas le « total » envoyé)" "$TOTAL_PANIER" \
    "$(docker compose exec -T php php -r "require 'app/Core/fonctions.php'; echo format_prix((float) '$(sql "SELECT SUM(total_ttc) FROM commande WHERE reference_achat = '$REF';")');")"
verifier "paiements acceptés, 4 derniers chiffres seulement" "2" \
    "$(sql "SELECT COUNT(*) FROM paiement p JOIN commande c ON c.id = p.id_commande WHERE c.reference_achat = '$REF' AND p.statut = 'ACCEPTE' AND p.carte_4_derniers = '1111';")"
verifier "panier vidé" 0 "$(curl -s -b "$A" "$BASE/api/panier" | json "d['nb_articles']")"
verifier_contient "page de confirmation" "Merci ! Votre commande est enregistrée." "$(page "$A" "/achat/$REF")"
FACTURE=$(page "$A" "/achat/$REF/facture")
verifier_contient "facture : TVA 20 %" "TVA 20 %" "$FACTURE"
verifier_contient "facture : feuille de style d'impression" "/assets/css/facture.css" "$FACTURE"
# Le plus récent des emails adressés à ce compte
MAIL=$(grep -l "^To: $EMAIL_A" var/mails/*.eml 2>/dev/null | xargs -r ls -t | head -1)
verifier "email de confirmation écrit" 1 "$( [[ -n $MAIL ]] && echo 1 || echo 0)"
verifier_contient "email : référence de l'achat" "$REF" "$(cat "$MAIL" 2>/dev/null)"
echo "--- Aucun numéro de carte complet conservé"
verifier "ni en base" 0 "$(sql "SELECT COUNT(*) FROM paiement WHERE carte_4_derniers <> SUBSTR(carte_4_derniers, 1, 4) OR LENGTH(carte_4_derniers) <> 4;")"
verifier "ni dans les emails" 0 "$(grep -l '4111 1111 1111 1111\|4111111111111111' var/mails/*.eml 2>/dev/null | wc -l)"
verifier "ni dans les journaux du serveur" 0 "$(docker compose logs php 2>&1 | grep -c '4111')"

echo "--- Refus de paiement : rien n'est créé"
api "$A" ajouter 30 1 > /dev/null
AVANT=$(nb_commandes "$EMAIL_A"); S30=$(stock 30)
verifier "carte invalide (Luhn) : 422" 422 "$(commander "$A" 'carte=4111 1111 1111 1112')"
verifier_contient "message « Numéro de carte invalide »" "Numéro de carte invalide" "$(cat "$TMP/corps")"
verifier "le numéro saisi n'est pas réaffiché" 0 "$(grep -c '4111 1111 1111 1112' "$TMP/corps")"
verifier "carte expirée : 422" 422 "$(commander "$A" annee=2020 mois=1)"
verifier_contient "message « Carte expirée »" "Carte expirée" "$(cat "$TMP/corps")"
verifier "aucune commande créée" "$AVANT" "$(nb_commandes "$EMAIL_A")"
verifier "stock inchangé" "$S30" "$(stock 30)"
verifier "panier conservé" 1 "$(curl -s -b "$A" "$BASE/api/panier" | json "d['nb_articles']")"

echo "--- Stock insuffisant : refus propre"
api "$A" ajouter 28 3 > /dev/null
sql "UPDATE produit SET stock = 2 WHERE id = 28;
COMMIT;" > /dev/null   # un autre client a acheté entre-temps
AVANT=$(nb_commandes "$EMAIL_A")
verifier "commande refusée, retour au panier" "303 /panier" "$(commander "$A") $(location)"
verifier_contient "message « Stock insuffisant »" "Stock insuffisant pour Miroir encadré en zellige" "$(page "$A" /panier)"
verifier "aucune commande créée" "$AVANT" "$(nb_commandes "$EMAIL_A")"
verifier "stock intact" 2 "$(stock 28)"
api "$A" retirer 28 > /dev/null

echo "--- Paiement à la livraison et double envoi"
verifier "commande à la livraison : 303" 303 "$(commander "$A" mode=LIVRAISON carte= cvv=)"
REF2=$(location | sed 's|.*/achat/||')
verifier "statut EN_ATTENTE, paiement EN_ATTENTE" "EN_ATTENTE/EN_ATTENTE" \
    "$(sql "SELECT c.statut || '/' || p.statut FROM commande c JOIN paiement p ON p.id_commande = c.id WHERE c.reference_achat = '$REF2';")"
AVANT=$(nb_commandes "$EMAIL_A")
verifier "2e envoi du même formulaire : retour au panier" "303 /panier" "$(commander "$A" mode=LIVRAISON) $(location)"
verifier "aucune commande en double" "$AVANT" "$(nb_commandes "$EMAIL_A")"

echo "--- Suivi et annulation"
NUM=$(sql "SELECT MIN(numero) FROM commande WHERE reference_achat = '$REF';")
verifier "mes commandes : 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' -b "$A" "$BASE/mes-commandes")"
verifier_contient "frise de suivi : étape courante marquée" 'aria-current="step"' "$(page "$A" "/commande/$NUM")"
S=$(sql "SELECT SUM(cl.quantite) FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande WHERE c.numero = '$NUM';")
P=$(sql "SELECT MIN(cl.id_produit) FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande WHERE c.numero = '$NUM';")
SP=$(stock "$P")
verifier "annulation : 303" 303 "$(poster "$A" "/commande/$NUM/annuler")"
verifier "commande ANNULEE, carte REMBOURSE" "ANNULEE/REMBOURSE" \
    "$(sql "SELECT c.statut || '/' || p.statut FROM commande c JOIN paiement p ON p.id_commande = c.id WHERE c.numero = '$NUM';")"
verifier "stock rendu" $((SP + S)) "$(stock "$P")"
poster "$A" "/commande/$NUM/annuler" > /dev/null
verifier_contient "2e annulation refusée avec un message" "ne peut plus être annulée" "$(page "$A" "/commande/$NUM")"

echo "--- Les commandes des autres restent privées"
inscrire "$B" "$EMAIL_B"
verifier "autre client : /achat/… → 404" 404 "$(curl -s -o /dev/null -w '%{http_code}' -b "$B" "$BASE/achat/$REF")"
verifier "autre client : /commande/… → 404" 404 "$(curl -s -o /dev/null -w '%{http_code}' -b "$B" "$BASE/commande/$NUM")"
NUM2=$(sql "SELECT MIN(numero) FROM commande WHERE reference_achat = '$REF2';")
verifier "autre client : annulation → 404" 404 "$(poster "$B" "/commande/$NUM2/annuler")"
verifier "… et la commande n'est pas annulée" EN_ATTENTE "$(sql "SELECT statut FROM commande WHERE numero = '$NUM2';")"

echo "--- Avis après livraison"
NUM3=$(sql "SELECT MAX(numero) FROM commande WHERE reference_achat = '$REF';")
P3=$(sql "SELECT MIN(cl.id_produit) FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande WHERE c.numero = '$NUM3';")
verifier "pas de formulaire d'avis avant livraison" 0 "$(page "$A" "/commande/$NUM3" | grep -c 'Donner mon avis')"
# Le vendeur expédie puis livre (étape 5) : simulé ici par le package.
# Une sous-requête n'est pas permise comme argument d'un appel PL/SQL (PLS-00405) : SELECT INTO d'abord.
sql "DECLARE v_id NUMBER; BEGIN
SELECT id INTO v_id FROM commande WHERE numero = '$NUM3';
pkg_commande.changer_statut(v_id, 'EXPEDIEE');
pkg_commande.changer_statut(v_id, 'LIVREE');
END;
/
COMMIT;" > /dev/null
verifier "formulaire d'avis après livraison" 1 "$(page "$A" "/commande/$NUM3" | grep -c 'Donner mon avis')"
poster "$A" "/produit/$P3/avis" note=9 retour="/commande/$NUM3" > /dev/null
verifier_contient "note 9 refusée" "Choisissez une note de 1 à 5" "$(page "$A" "/commande/$NUM3")"
poster "$A" "/produit/$P3/avis" note=5 "commentaire=Parfait <b>vraiment</b>" retour="/commande/$NUM3" > /dev/null
verifier_contient "avis publié" "Merci pour votre avis" "$(page "$A" "/commande/$NUM3")"
verifier_contient "avis affiché (échappé) sur la fiche produit" "Parfait &lt;b&gt;vraiment&lt;/b&gt;" "$(page "$A" "/produit/$P3")"
poster "$A" "/produit/$P3/avis" note=4 retour="/commande/$NUM3" > /dev/null
verifier_contient "2e avis refusé (PKG_AVIS)" "déjà donné votre avis" "$(page "$A" "/commande/$NUM3")"

echo "--- Règles de rôle"
V="$TMP/vendeur"; : > "$V"
poster "$V" /connexion email=youssef.benali@exemple.ma 'mot_de_passe=Demo1234!' > /dev/null
api "$V" ajouter 1 1 > /dev/null
verifier "vendeur : achat dans sa propre boutique refusé (422)" 422 "$(cat "$TMP/code")"
verifier_contient "message explicite" "propre boutique" "$(cat "$TMP/json")"
ADM="$TMP/admin"; : > "$ADM"
poster "$ADM" /connexion email=admin@exemple.ma 'mot_de_passe=Demo1234!' > /dev/null
verifier "admin : /commande interdit (403)" 403 "$(curl -s -o /dev/null -w '%{http_code}' -b "$ADM" "$BASE/commande")"

echo "--- Deux clients achètent EN MÊME TEMPS le dernier exemplaire"
sql "UPDATE produit SET stock = 1 WHERE id = 29;
COMMIT;" > /dev/null
api "$A" ajouter 29 1 > /dev/null; api "$B" ajouter 29 1 > /dev/null
JA=$(jeton "$A" /commande); JB=$(jeton "$B" /commande)
lancer() { curl -s -o /dev/null -D "$TMP/entetes-$1" -b "$2" -c "$2" --data-urlencode "_csrf=$3" \
    --data-urlencode mode=LIVRAISON --data-urlencode 'adresse=12 rue des Orangers' --data-urlencode ville=Rabat \
    --data-urlencode 'telephone=0612345678' "$BASE/commande"; }
lancer a "$A" "$JA" & lancer b "$B" "$JB" & wait
DESTINATIONS=$(for x in a b; do grep -i '^location:' "$TMP/entetes-$x" | tr -d '\r' | cut -d' ' -f2 | sed 's|/achat/.*|/achat|'; done | sort | tr '\n' ' ')
verifier "un achat accepté, l'autre renvoyé au panier" "/achat /panier " "$DESTINATIONS"
verifier "stock à 0, jamais négatif" 0 "$(stock 29)"
verifier "une seule ligne de commande pour ce produit" 1 \
    "$(sql "SELECT COUNT(*) FROM commande_ligne cl JOIN commande c ON c.id = cl.id_commande JOIN utilisateur u ON u.id = c.id_client WHERE cl.id_produit = 29 AND u.email LIKE 'test-cmd-%';")"

echo "--- Serveur"
verifier "les processus PHP ne tournent pas en root" 0 "$(docker compose exec -T php sh -c \
    'for p in /proc/[0-9]*; do [ "$(basename $p)" = 1 ] && continue; n=$(sed -n "s/^Name:\t//p" $p/status 2>/dev/null); [ "$n" = apache2 ] && sed -n "s/^Uid:\t\([0-9]*\).*/\1/p" $p/status; done' | grep -c '^0$')"

echo
echo "BILAN HTTP COMMANDE : $OK OK, $ECHECS ÉCHEC"
[[ $ECHECS -eq 0 ]]
