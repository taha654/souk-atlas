#!/bin/bash
# =============================================================================
# Tests HTTP de l'étape 6 : petites annonces, photos, favoris, signalements,
# messagerie (dont l'API de polling) et expiration par le job planifié.
#   ./tests/http/test_annonces.sh
# Critère : « Une annonce est publiée, reçoit un message, puis expire via le job ».
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
source tests/http/outils.sh

nettoyer() { supprimer_comptes_test; rm -rf "$TMP"; }
supprimer_comptes_test
trap nettoyer EXIT

A="$TMP/auteur"; B="$TMP/acheteur"; X="$TMP/intrus"; ADM="$TMP/admin"
: > "$A"; : > "$B"; : > "$X"; : > "$ADM"
python3 -c "
import base64; open('$TMP/photo.png','wb').write(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='))"
inscrire "$A" test-ann-auteur@exemple.ma > /dev/null
inscrire "$B" test-ann-acheteur@exemple.ma > /dev/null
inscrire "$X" test-ann-intrus@exemple.ma VENDEUR > /dev/null
connecter "$ADM" admin@exemple.ma > /dev/null

echo "--- Publication"
verifier "visiteur : /annonces/nouvelle → connexion" 303 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/annonces/nouvelle")"
verifier "admin : publier interdit (403)" 403 "$(code "$ADM" /annonces/nouvelle)"
verifier "titre trop court : 422" 422 "$(poster "$A" /annonces titre=Vélo 'description=Vélo à vendre' prix=500 ville=Rabat id_categorie=24)"
verifier "publication : 303" 303 "$(poster "$A" /annonces 'titre=Vélo de ville Zéphyr test' 'description=Vélo de ville, très bon état, révisé.' prix=900 ville=Rabat id_categorie=24)"
ID=$(location | sed 's|.*/mes-annonces/||')
verifier "redirection vers la gestion de l'annonce" 1 "$(grep -c '^[0-9]\+$' <<< "$ID")"
verifier "annonce ordinaire : en ligne sans modération (score C++ faible)" EN_LIGNE "$(sql "SELECT statut FROM annonce WHERE id = $ID;")"
verifier "expiration dans 30 jours" 30 "$(sql "SELECT ROUND(date_expiration - SYSDATE) FROM annonce WHERE id = $ID;")"
verifier "fiche publique : 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/annonce/$ID")"
verifier_contient "trouvée par la recherche sans accents (« zephyr »)" "Vélo de ville Zéphyr test" "$(curl -s "$BASE/annonces?q=zephyr")"
verifier_contient "trouvée par ville en minuscules (« rabat »)" "Vélo de ville Zéphyr test" "$(curl -s "$BASE/annonces?ville=rabat&categorie=22")"

echo "--- Gestion par l'auteur seulement"
verifier "photo : 303" 303 "$(envoyer_fichier "$A" "/mes-annonces/$ID/photos" "$TMP/photo.png")"
verifier "photo enregistrée" 1 "$(sql "SELECT COUNT(*) FROM annonce_photo WHERE id_annonce = $ID;")"
verifier "autre membre : page de gestion → 404" 404 "$(code "$B" "/mes-annonces/$ID")"
verifier "autre membre : envoi de photo → 404" 404 "$(envoyer_fichier "$B" "/mes-annonces/$ID/photos" "$TMP/photo.png")"
verifier "autre membre : marquer vendue → 404" 404 "$(poster "$B" "/mes-annonces/$ID/vendue")"
poster "$A" "/mes-annonces/$ID" 'titre=Vélo de ville Zéphyr révisé' 'description=Vélo de ville, très bon état, révisé.' prix=850 ville=Rabat id_categorie=24 > /dev/null
verifier "modification par l'auteur" "850" "$(sql "SELECT prix FROM annonce WHERE id = $ID;")"

echo "--- Favoris et signalement"
poster "$B" "/annonce/$ID/favori" favori=1 > /dev/null
verifier_contient "favori ajouté" "Vélo de ville Zéphyr révisé" "$(page "$B" /favoris)"
poster "$B" "/annonce/$ID/favori" favori=0 > /dev/null
verifier "favori retiré" 0 "$(sql "SELECT COUNT(*) FROM favori WHERE id_annonce = $ID;")"
poster "$B" "/annonce/$ID/signaler" motif=ARNAQUE 'commentaire=Prix suspect' > /dev/null
verifier "signalement enregistré, ouvert" OUVERT "$(sql "SELECT statut FROM signalement WHERE id_annonce = $ID;")"
poster "$B" "/annonce/$ID/signaler" motif=ARNAQUE > /dev/null
verifier_contient "2e signalement refusé" "déjà signalé" "$(page "$B" "/annonce/$ID")"

echo "--- Messagerie"
poster "$A" "/annonce/$ID/contacter" 'message=Je me contacte' > /dev/null
verifier_contient "se contacter soi-même refusé" "contacter vous-même" "$(page "$A" "/annonce/$ID")"
verifier "contacter le vendeur : 303 vers la conversation" 303 "$(poster "$B" "/annonce/$ID/contacter" 'message=Bonjour, <b>toujours</b> disponible ?')"
CONV=$(location | sed 's|.*/messages/||')
verifier_contient "badge « non lu » chez l'auteur" "non lu(s)" "$(page "$A" /annonces)"
verifier_contient "l'auteur lit le message (HTML échappé)" "Bonjour, &lt;b&gt;toujours&lt;/b&gt; disponible ?" "$(page "$A" "/messages/$CONV")"
verifier "… et il est marqué lu" 0 "$(sql "SELECT COUNT(*) FROM message WHERE id_conversation = $CONV AND lu = 0;")"
DERNIER=$(sql "SELECT MAX(id) FROM message WHERE id_conversation = $CONV;")
verifier "réponse par l'API (en-tête CSRF) : 201" 201 \
    "$(curl -s -o /dev/null -w '%{http_code}' -b "$A" -c "$A" -H "X-CSRF-Token: $(jeton "$A")" --data 'message=Oui, il est disponible.' "$BASE/api/messages/$CONV")"
verifier "polling : l'acheteur reçoit uniquement le nouveau message" "1 Oui, il est disponible." \
    "$(page "$B" "/api/messages/$CONV?apres=$DERNIER" | json "str(len(d['messages'])) + ' ' + d['messages'][0]['contenu']")"
verifier "polling sans nouveauté : liste vide" 0 \
    "$(page "$B" "/api/messages/$CONV?apres=$(sql "SELECT MAX(id) FROM message WHERE id_conversation = $CONV;")" | json "len(d['messages'])")"
verifier "message vide refusé (422)" 422 \
    "$(curl -s -o /dev/null -w '%{http_code}' -b "$A" -c "$A" -H "X-CSRF-Token: $(jeton "$A")" --data 'message=   ' "$BASE/api/messages/$CONV")"
verifier "intrus : conversation → 404" 404 "$(code "$X" "/messages/$CONV")"
verifier "intrus : API de polling → 404" 404 "$(code "$X" "/api/messages/$CONV?apres=0")"
verifier "intrus : écrire dans la conversation → 404" 404 "$(poster "$X" "/messages/$CONV" 'message=coucou')"

echo "--- Expiration par le job planifié"
sql "UPDATE annonce SET date_publication = SYSDATE - 31, date_expiration = SYSDATE - 1 WHERE id = $ID;
COMMIT;" > /dev/null
sql "BEGIN DBMS_SCHEDULER.RUN_JOB('JOB_EXPIRATION_ANNONCES', use_current_session => TRUE); END;
/" > /dev/null
verifier "le job a expiré l'annonce" EXPIREE "$(sql "SELECT statut FROM annonce WHERE id = $ID;")"
verifier "expirée : invisible du public" 404 "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/annonce/$ID")"
verifier_contient "l'auteur la voit « Expirée »" "Expirée" "$(page "$A" /mes-annonces)"
verifier "la conversation reste lisible" 200 "$(code "$B" "/messages/$CONV")"
poster "$A" "/mes-annonces/$ID/renouveler" > /dev/null
verifier "renouvelée : de nouveau en ligne" "EN_LIGNE 200" \
    "$(sql "SELECT statut FROM annonce WHERE id = $ID;") $(curl -s -o /dev/null -w '%{http_code}' "$BASE/annonce/$ID")"
poster "$A" "/mes-annonces/$ID/vendue" > /dev/null
verifier "marquée vendue" VENDUE "$(sql "SELECT statut FROM annonce WHERE id = $ID;")"
poster "$A" "/mes-annonces/$ID/vendue" > /dev/null
verifier_contient "vendre deux fois : refusé avec un message" "Seule une annonce en ligne" "$(page "$A" /mes-annonces)"

bilan ANNONCES
