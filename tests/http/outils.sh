#!/bin/bash
# =============================================================================
# Fonctions communes aux tests HTTP (à charger avec : source tests/http/outils.sh)
# Un "jar" est le fichier de cookies d'un navigateur simulé par curl.
# =============================================================================
BASE="${BASE:-http://localhost:8000}"
TMP=$(mktemp -d)
OK=0
ECHECS=0
MDP_DEMO='Demo1234!'

verifier() {           # verifier "libellé" attendu obtenu
    if [[ "$2" == "$3" ]]; then OK=$((OK + 1)); echo "OK     $1"
    else ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — attendu : $2, obtenu : $3"; fi
}
verifier_contient() {  # verifier_contient "libellé" "texte cherché" "texte"
    if grep -qF -- "$2" <<< "$3"; then OK=$((OK + 1)); echo "OK     $1"
    else ECHECS=$((ECHECS + 1)); echo "ÉCHEC  $1 — « $2 » introuvable"; fi
}
bilan() {              # bilan "NOM" : affiche le bilan, code de retour 0 si tout passe
    echo; echo "BILAN HTTP $1 : $OK OK, $ECHECS ÉCHEC"
    [[ $ECHECS -eq 0 ]]
}

# Requête SQL dans le schéma SOUK ; résultat sans espaces (un ordre SQL par ligne !)
sql() {
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' <<< "SET PAGESIZE 0 FEEDBACK OFF HEADING OFF
$1" | tr -d ' \t\r\n'
}
# Supprime les comptes test-…@exemple.ma et tout ce qui en dépend, y compris les
# FICHIERS des photos qu'ils ont envoyées (produits et annonces)
supprimer_comptes_test() {
    docker compose exec -T oracle bash -c 'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' <<'SQL' \
        | { grep '^/uploads/' || true; } | while read -r chemin; do rm -f "public$chemin"; done   # grep sans résultat : pas une erreur
SET PAGESIZE 0 FEEDBACK OFF HEADING OFF LINESIZE 300
SELECT ph.chemin FROM produit_photo ph JOIN produit p ON p.id = ph.id_produit JOIN boutique b ON b.id = p.id_boutique
  JOIN utilisateur u ON u.id = b.id_vendeur WHERE u.email LIKE 'test-%' AND ph.chemin LIKE '/uploads/%'
UNION ALL
SELECT ph.chemin FROM annonce_photo ph JOIN annonce a ON a.id = ph.id_annonce
  JOIN utilisateur u ON u.id = a.id_utilisateur WHERE u.email LIKE 'test-%' AND ph.chemin LIKE '/uploads/%';
EXIT
SQL
    # EXIT : sans lui, SQL*Plus attendrait la suite au clavier
    docker compose exec -T oracle bash -c \
        'sqlplus -s -L "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"' > /dev/null <<'SQL'
@/opt/souk/database/tests/nettoyer_comptes_test.sql
EXIT
SQL
    grep -l '^To: test-' var/mails/*.eml 2>/dev/null | xargs -r rm -f || true
}

# Jeton CSRF lu dans <meta name="csrf-token"> (présente sur toutes les pages)
jeton() { curl -s -b "$1" -c "$1" "$BASE${2:-/}" | grep -o 'name="csrf-token" content="[^"]*"' | head -1 | cut -d'"' -f4; }
code() { curl -s -o /dev/null -w '%{http_code}' -b "$1" -c "$1" "$BASE$2"; }
page() { curl -s -b "$1" -c "$1" "$BASE$2"; }
location() { grep -i '^location:' "$TMP/entetes" | tr -d '\r' | cut -d' ' -f2; }
json() { python3 -c "import json, sys; d = json.load(sys.stdin); print($1)"; }
# poster jar url champ=valeur… → code HTTP ; corps dans $TMP/corps, en-têtes dans $TMP/entetes
poster() {
    local jar="$1" url="$2"; shift 2
    local args=(); for c in "$@"; do args+=(--data-urlencode "$c"); done
    curl -s -o "$TMP/corps" -D "$TMP/entetes" -w '%{http_code}' -b "$jar" -c "$jar" \
        --data-urlencode "_csrf=$(jeton "$jar")" "${args[@]}" "$BASE$url"
}
# envoyer_fichier jar url chemin_local [nom_annoncé] [type_annoncé] → code HTTP (formulaire multipart)
envoyer_fichier() {
    curl -s -o "$TMP/corps" -D "$TMP/entetes" -w '%{http_code}' -b "$1" -c "$1" \
        -F "_csrf=$(jeton "$1")" -F "photo=@$3;filename=${4:-$(basename "$3")};type=${5:-image/png}" "$BASE$2"
}
connecter() { poster "$1" /connexion "email=$2" "mot_de_passe=${3:-$MDP_DEMO}"; }
inscrire() {  # inscrire jar email ROLE
    poster "$1" /inscription "role=${3:-CLIENT}" "nom=Compte Test" "email=$2" \
        mot_de_passe=motdepasse1 confirmation=motdepasse1
}
