#!/bin/sh
# Teste l'exécutable comme PHP l'utilise : JSON sur stdin, JSON et code de sortie
moteur="$1"
echecs=0

verifier() {   # verifier <description> <entrée> <code attendu> <texte attendu dans la sortie>
    sortie=$(printf '%s' "$2" | "$moteur")
    code=$?
    if [ "$code" -eq "$3" ] && printf '%s' "$sortie" | grep -qF -- "$4"; then
        echo "OK      $1"
    else
        echo "ÉCHEC   $1 (code $code, sortie : $sortie)"
        echecs=$((echecs + 1))
    fi
}

verifier "succès" '{"action":"recommandations","paniers":[[1,2],[1,2]]}' 0 '"ok":true'
verifier "réponse sur une seule ligne" '{"action":"risque_annonce","annonce":{"prix":5}}' 0 '"niveau":"FAIBLE"'
verifier "JSON invalide → code 2" '{"action":' 2 '"ok":false'
verifier "entrée vide → code 2" '' 2 'JSON invalide'
verifier "action inconnue → code 2" '{"action":"pirater"}' 2 'action inconnue'
verifier "accents conservés" '{"action":"risque_annonce","annonce":{"titre":"Vélo","prix":5,"description":"URGENT, payer d’avance"}}' 0 'expressions suspectes'

[ "$echecs" -eq 0 ]
