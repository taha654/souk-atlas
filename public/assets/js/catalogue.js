// =============================================================================
// Catalogue : filtres, tri et pagination SANS rechargement de la page.
//
// La page fonctionne déjà sans JavaScript (formulaire GET classique). Ce module
// l'améliore :
//   1. il écoute les changements du formulaire #filtres ;
//   2. il demande les résultats à /api/produits avec fetch ;
//   3. il reconstruit la liste avec le <template id="modele-carte"> ;
//   4. il met à jour l'URL avec history.pushState (lien partageable, bouton
//      « Précédent » fonctionnel grâce à l'événement popstate).
// =============================================================================
import { getJson, debounce, estAnnulation } from './api.js';

const formulaire = document.getElementById('filtres');
const liste = document.getElementById('liste-produits');
const modele = document.getElementById('modele-carte');
const nbResultats = document.getElementById('nb-resultats');
const aucunResultat = document.getElementById('aucun-resultat');
const pagination = document.getElementById('pagination');
const titre = document.getElementById('titre-catalogue');
const filAriane = document.getElementById('zone-fil-ariane');

// Requête en cours, annulée si une nouvelle arrive avant sa réponse : sans
// cela, une réponse lente pourrait écraser une réponse plus récente
let requeteEnCours = null;

/** Paramètres du formulaire → "q=samsung&tri=prix_asc" (champs vides retirés) */
function parametresDuFormulaire(page = 1) {
    const params = new URLSearchParams();
    for (const [nom, valeur] of new FormData(formulaire)) {
        if (valeur !== '' && !(nom === 'tri' && valeur === 'pertinence')) params.set(nom, valeur);
    }
    if (page > 1) params.set('page', String(page));
    return params;
}

/** Remet le formulaire dans l'état décrit par l'URL (après « Précédent ») */
function remplirFormulaire(params) {
    formulaire.elements.q.value = params.get('q') ?? '';
    formulaire.elements.prix_min.value = params.get('prix_min') ?? '';
    formulaire.elements.prix_max.value = params.get('prix_max') ?? '';
    formulaire.elements.tri.value = params.get('tri') ?? 'pertinence';
    formulaire.elements.en_stock.checked = params.get('en_stock') === '1';
    const categorie = params.get('categorie') ?? '';
    for (const radio of formulaire.querySelectorAll('input[name="categorie"]')) {
        radio.checked = radio.value === categorie;
    }
}

/** Charge et affiche les résultats ; `historique` : 'pousser', 'remplacer' ou rien */
async function charger(params, historique = 'pousser') {
    requeteEnCours?.abort();
    requeteEnCours = new AbortController();
    // aria-busy : signale aux technologies d'assistance que la zone se met à jour
    liste.setAttribute('aria-busy', 'true');

    try {
        const donnees = await getJson(`/api/produits?${params}`, { signal: requeteEnCours.signal });
        afficher(donnees);
        const url = donnees.url; // URL canonique calculée par le serveur
        if (historique === 'pousser' && url !== location.pathname + location.search) {
            history.pushState(null, '', url);
        }
    } catch (erreur) {
        if (estAnnulation(erreur)) return; // remplacée par une requête plus récente
        nbResultats.textContent = 'Le chargement a échoué. Réessayez.';
    } finally {
        liste.removeAttribute('aria-busy');
    }
}

function afficher({ produits, total, page, pages, filtres }) {
    // replaceChildren : vide la liste et ajoute les nouvelles cartes en une opération
    liste.replaceChildren(...produits.map(creerCarte));
    aucunResultat.hidden = produits.length > 0;
    nbResultats.textContent = total === 0
        ? 'Aucun produit trouvé'
        : `${total} produit${total > 1 ? 's' : ''} trouvé${total > 1 ? 's' : ''}`;
    titre.textContent = filtres.q ? `Résultats pour « ${filtres.q} »` : 'Catalogue';
    afficherPagination(page, pages);
    // Le fil d'Ariane dépend de la catégorie : on le masque plutôt que de le recalculer
    if (filAriane) filAriane.hidden = true;
}

/** Clone le modèle de carte et le remplit. Uniquement textContent et des attributs : aucun HTML injecté */
function creerCarte(produit) {
    const carte = modele.content.firstElementChild.cloneNode(true);
    const champ = (nom) => carte.querySelector(`[data-champ="${nom}"]`);

    champ('url').href = produit.url;
    champ('photo').src = produit.photo ?? '/assets/img/aucune-photo.svg';
    champ('nom').textContent = produit.nom;
    champ('boutique').textContent = produit.boutique;
    champ('prix').textContent = produit.prix_courant_ttc_texte;

    const enPromo = produit.pourcentage_promo > 0;
    champ('promo').hidden = !enPromo;
    champ('promo').textContent = enPromo ? `-${Math.trunc(produit.pourcentage_promo)} %` : '';
    champ('ancien-prix').hidden = !enPromo;
    champ('ancien-prix-texte').textContent = produit.prix_ttc_texte;

    champ('note').textContent = texteNote(produit.note_moyenne, produit.nb_avis);
    champ('stock').textContent = texteStock(produit.stock);
    champ('stock').classList.toggle('stock--epuise', produit.stock === 0);
    return carte;
}

// Mêmes règles que texte_note() et texte_stock() dans app/Core/fonctions.php
function texteNote(note, nbAvis) {
    if (note === null || nbAvis === 0) return "Pas encore d'avis";
    return `★ ${note.toFixed(1).replace('.', ',')} sur 5 (${nbAvis} avis)`;
}

function texteStock(stock) {
    if (stock === 0) return 'Épuisé';
    if (stock <= 5) return `Plus que ${stock} en stock`;
    return 'En stock';
}

/** 1 … 4 5 [6] 7 8 … 20 (null = « … ») : même algorithme que pages_a_afficher() en PHP */
function pagesAAfficher(page, pages) {
    const liste = [];
    let precedent = 0;
    for (let n = 1; n <= pages; n++) {
        if (n === 1 || n === pages || Math.abs(n - page) <= 2) {
            if (n - precedent > 1) liste.push(null);
            liste.push(n);
            precedent = n;
        }
    }
    return liste;
}

function afficherPagination(page, pages) {
    if (pages <= 1) {
        pagination.replaceChildren();
        return;
    }
    const ul = document.createElement('ul');
    ul.className = 'pagination__liste';
    const lien = (numero, texte, courant = false) => {
        const li = document.createElement('li');
        const a = document.createElement('a');
        a.href = `/catalogue?${parametresDuFormulaire(numero)}`;
        a.textContent = texte;
        if (courant) a.setAttribute('aria-current', 'page');
        else a.dataset.page = String(numero);
        li.append(a);
        return li;
    };
    if (page > 1) ul.append(lien(page - 1, 'Précédent'));
    for (const numero of pagesAAfficher(page, pages)) {
        if (numero === null) {
            const li = document.createElement('li');
            li.setAttribute('aria-hidden', 'true');
            li.textContent = '…';
            ul.append(li);
        } else {
            ul.append(lien(numero, String(numero), numero === page));
        }
    }
    if (page < pages) ul.append(lien(page + 1, 'Suivant'));
    pagination.replaceChildren(ul);
}

// Sur téléphone, filtres repliés au chargement : les produits sont visibles tout de suite
if (window.matchMedia('(max-width: 760px)').matches) {
    formulaire.querySelector('.filtres__bascule').open = false;
}

// ----- Événements -----

// Cases, boutons radio et liste de tri : mise à jour immédiate
formulaire.addEventListener('change', (evenement) => {
    if (evenement.target.matches('input[type="number"], input[type="search"]')) return; // gérés plus bas
    charger(parametresDuFormulaire());
});

// Saisie au clavier (mots-clés, prix) : on attend une pause de 400 ms (debounce)
const chargerApresPause = debounce(() => charger(parametresDuFormulaire()), 400);
formulaire.addEventListener('input', (evenement) => {
    if (evenement.target.matches('input[type="number"], input[type="search"]')) chargerApresPause();
});

// Entrée ou bouton « Appliquer » : pas de rechargement, même traitement
formulaire.addEventListener('submit', (evenement) => {
    evenement.preventDefault();
    charger(parametresDuFormulaire());
});

document.getElementById('effacer-filtres').addEventListener('click', (evenement) => {
    evenement.preventDefault();
    formulaire.reset();
    remplirFormulaire(new URLSearchParams());
    charger(new URLSearchParams());
});

// Délégation d'événements : un seul écouteur sur <nav> pour tous les liens de
// pagination, y compris ceux créés plus tard par afficherPagination()
pagination.addEventListener('click', (evenement) => {
    const lien = evenement.target.closest('a[data-page]');
    if (!lien) return;
    evenement.preventDefault();
    charger(parametresDuFormulaire(Number(lien.dataset.page)));
    titre.scrollIntoView({ behavior: 'smooth', block: 'start' });
});

// Bouton « Précédent » / « Suivant » du navigateur : on revient à l'état de l'URL
window.addEventListener('popstate', () => {
    const params = new URLSearchParams(location.search);
    remplirFormulaire(params);
    charger(params, 'aucun');
});
