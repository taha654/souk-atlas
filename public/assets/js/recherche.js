// =============================================================================
// Autocomplétion de la barre de recherche (motif ARIA « combobox »).
//
// - debounce : la requête part 250 ms après la dernière frappe ;
// - AbortController : une requête dépassée est annulée ;
// - clavier : ↓ ↑ pour choisir, Entrée pour ouvrir, Échap pour fermer ;
// - aria-activedescendant : le lecteur d'écran annonce la suggestion choisie
//   alors que le focus reste dans le champ de saisie.
// Sans JavaScript, le formulaire envoie simplement ?q=… vers /catalogue.
// =============================================================================
import { getJson, debounce, estAnnulation } from './api.js';

const champ = document.getElementById('recherche');
const liste = document.getElementById('suggestions');
const LONGUEUR_MIN = 2;

let suggestions = [];
let indexActif = -1;
let requeteEnCours = null;

function fermer() {
    liste.hidden = true;
    liste.replaceChildren();
    champ.setAttribute('aria-expanded', 'false');
    champ.removeAttribute('aria-activedescendant');
    suggestions = [];
    indexActif = -1;
}

function afficher(resultats) {
    suggestions = resultats;
    indexActif = -1;
    if (resultats.length === 0) {
        fermer();
        return;
    }
    liste.replaceChildren(...resultats.map((suggestion, i) => {
        const option = document.createElement('li');
        option.id = `suggestion-${i}`;
        option.setAttribute('role', 'option');
        option.setAttribute('aria-selected', 'false');
        option.textContent = suggestion.nom; // textContent : le nom n'est jamais interprété comme du HTML
        // mousedown (et non click) : il se produit AVANT que le champ perde le focus
        option.addEventListener('mousedown', (evenement) => {
            evenement.preventDefault();
            ouvrir(suggestion);
        });
        return option;
    }));
    liste.hidden = false;
    champ.setAttribute('aria-expanded', 'true');
}

function activer(index) {
    const options = liste.querySelectorAll('[role="option"]');
    options.forEach((option, i) => option.setAttribute('aria-selected', String(i === index)));
    indexActif = index;
    if (index >= 0) {
        champ.setAttribute('aria-activedescendant', options[index].id);
        options[index].scrollIntoView({ block: 'nearest' });
    } else {
        champ.removeAttribute('aria-activedescendant');
    }
}

function ouvrir(suggestion) {
    location.href = `/produit/${suggestion.id}`;
}

const chercher = debounce(async (texte) => {
    requeteEnCours?.abort();
    requeteEnCours = new AbortController();
    try {
        const resultats = await getJson(`/api/suggestions?q=${encodeURIComponent(texte)}`,
            { signal: requeteEnCours.signal });
        // Le champ a pu changer pendant la requête : on n'affiche que si c'est encore pertinent
        if (champ.value.trim() === texte) afficher(resultats);
    } catch (erreur) {
        if (!estAnnulation(erreur)) fermer();
    }
}, 250);

champ.addEventListener('input', () => {
    const texte = champ.value.trim();
    if (texte.length < LONGUEUR_MIN) {
        requeteEnCours?.abort();
        fermer();
        return;
    }
    chercher(texte);
});

champ.addEventListener('keydown', (evenement) => {
    if (liste.hidden) return;
    switch (evenement.key) {
        case 'ArrowDown':
            evenement.preventDefault();
            activer((indexActif + 1) % suggestions.length);
            break;
        case 'ArrowUp':
            evenement.preventDefault();
            activer(indexActif <= 0 ? suggestions.length - 1 : indexActif - 1);
            break;
        case 'Enter':
            // Une suggestion choisie : on l'ouvre ; sinon, recherche normale (envoi du formulaire)
            if (indexActif >= 0) {
                evenement.preventDefault();
                ouvrir(suggestions[indexActif]);
            }
            break;
        case 'Escape':
            fermer();
            break;
    }
});

// Clic ailleurs ou Tab vers un autre élément : on ferme la liste
champ.addEventListener('blur', fermer);
