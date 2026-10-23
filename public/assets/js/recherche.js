// =============================================================================
// Autocomplétion de la barre de recherche (motif ARIA « combobox »).
//
// - debounce : la requête part 250 ms après la dernière frappe ;
// - AbortController : une requête dépassée est annulée ;
// - clavier : ↓ ↑ pour choisir, Entrée pour ouvrir, Échap pour fermer ;
// - aria-activedescendant : le lecteur d'écran annonce la suggestion choisie
//   alors que le focus reste dans le champ de saisie ;
// - fautes de frappe (étape 10) : si le serveur trouve peu de produits, la
//   recherche TOLÉRANTE du module WebAssembly complète la liste
//   (« smartphon samsng » → « Smartphone Samsung… »).
// Sans JavaScript, le formulaire envoie simplement ?q=… vers /catalogue.
// =============================================================================
import { getJson, debounce, estAnnulation } from './api.js';
import { obtenirMoteur } from './wasm.js';

const champ = document.getElementById('recherche');
const liste = document.getElementById('suggestions');
const LONGUEUR_MIN = 2;
const NB_SUGGESTIONS = 8;

let indexTolerant = null;   // promesse : titres du catalogue chargés dans le moteur

/** Index chargé au premier usage (titres de tous les produits, une seule requête) */
function obtenirIndex() {
    indexTolerant ??= (async () => {
        const [moteur, titres] = await Promise.all([obtenirMoteur(), getJson('/api/titres')]);
        const index = moteur.creerIndex();
        for (const { id, nom } of titres) index.ajouter(id, nom);
        liste.dataset.moteur = moteur.nom;   // visible dans les outils de développement (et les tests)
        return index;
    })().catch((erreur) => {
        indexTolerant = null;   // nouvel essai à la prochaine frappe
        throw erreur;
    });
    return indexTolerant;
}

/** Complète les suggestions du serveur par des correspondances approchées */
async function completer(texte, duServeur) {
    if (duServeur.length >= NB_SUGGESTIONS) return duServeur;
    try {
        const index = await obtenirIndex();
        const dejaLa = new Set(duServeur.map((s) => s.id));
        const approchees = index.rechercher(texte, NB_SUGGESTIONS)
            .filter((s) => !dejaLa.has(s.id))
            .map((s) => ({ id: s.id, nom: s.nom, approchee: true }));
        return [...duServeur, ...approchees].slice(0, NB_SUGGESTIONS);
    } catch {
        return duServeur;   // pas de recherche tolérante : les suggestions du serveur suffisent
    }
}

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
        if (suggestion.approchee) {
            const marque = document.createElement('span');
            marque.className = 'suggestion__approchee';
            marque.textContent = ' — orthographe approchée';
            option.append(marque);
        }
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
        const resultats = await completer(texte, await getJson(`/api/suggestions?q=${encodeURIComponent(texte)}`,
            { signal: requeteEnCours.signal }));
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
