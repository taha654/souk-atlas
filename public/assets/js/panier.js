// =============================================================================
// Panier dynamique (amélioration progressive : sans JS, les formulaires POST
// classiques de /panier/… fonctionnent déjà).
//
//  - fiche produit : « Ajouter au panier » sans rechargement, badge mis à jour ;
//  - page panier : quantité modifiée à la saisie (debounce), retrait d'une ligne,
//    totaux recalculés PAR LE SERVEUR (jamais en JavaScript).
//
// Les POST portent le jeton CSRF dans l'en-tête X-CSRF-Token (lu dans la <meta>).
// =============================================================================
import { debounce } from './api.js';

const jetonCsrf = document.querySelector('meta[name="csrf-token"]')?.content ?? '';
const badge = document.getElementById('badge-panier');
const message = document.getElementById('message-panier');

/** Envoie une opération à /api/panier ; renvoie { ok, donnees } */
async function operation(nom, idProduit, quantite) {
    const corps = new URLSearchParams({ operation: nom, id_produit: idProduit });
    if (quantite !== undefined) corps.set('quantite', quantite);
    const reponse = await fetch('/api/panier', {
        method: 'POST',
        headers: { 'X-CSRF-Token': jetonCsrf, Accept: 'application/json' },
        body: corps,
    });
    const donnees = await reponse.json().catch(() => ({}));
    if (donnees.nb_articles !== undefined) majBadge(donnees.nb_articles);
    return { ok: reponse.ok, donnees };
}

function majBadge(nb) {
    if (!badge) return;
    badge.textContent = String(nb);
    badge.hidden = nb === 0;
}

function annoncer(texte, erreur = false) {
    if (!message) return;
    message.textContent = texte;
    message.classList.toggle('message-panier--erreur', erreur);
}

// ----- Fiche produit : ajout sans rechargement -----
for (const formulaire of document.querySelectorAll('form[data-panier-ajout]')) {
    formulaire.addEventListener('submit', async (evenement) => {
        evenement.preventDefault();
        const bouton = formulaire.querySelector('button[type="submit"]');
        bouton.disabled = true; // évite les doubles clics pendant la requête
        try {
            const { ok, donnees } = await operation('ajouter',
                formulaire.elements.id_produit.value, formulaire.elements.quantite.value);
            annoncer(ok ? 'Ajouté au panier.' : donnees.message ?? 'Ajout impossible.', !ok);
        } catch {
            formulaire.submit(); // réseau en panne côté JS : on retombe sur le formulaire classique
        } finally {
            bouton.disabled = false;
        }
    });
}

// ----- Page panier : quantités et retraits -----
const tableau = document.querySelector('.tableau-panier');

function majPagePanier(donnees) {
    for (const ligne of donnees.lignes) {
        const cellule = document.querySelector(`tr[data-ligne="${ligne.id_produit}"] [data-total-ligne]`);
        if (cellule) cellule.textContent = ligne.total_ligne_ttc_texte;
    }
    // Lignes disparues côté serveur (quantité 0 ou retrait) : on les enlève du tableau
    const restantes = new Set(donnees.lignes.map((l) => String(l.id_produit)));
    for (const tr of document.querySelectorAll('tr[data-ligne]')) {
        if (!restantes.has(tr.dataset.ligne)) tr.remove();
    }
    document.querySelector('[data-total="ht"]').textContent = donnees.total_ht_texte;
    document.querySelector('[data-total="tva"]').textContent = donnees.tva_texte;
    document.querySelector('[data-total="ttc"]').textContent = donnees.total_ttc_texte;
    if (donnees.lignes.length === 0) {
        document.getElementById('panier').hidden = true;
        document.getElementById('panier-vide').hidden = false;
    }
}

if (tableau) {
    // Avec JS, les boutons « Mettre à jour » deviennent inutiles
    for (const bouton of document.querySelectorAll('[data-sans-js]')) bouton.hidden = true;

    const modifier = debounce(async (champ, idProduit) => {
        const { ok, donnees } = await operation('modifier', idProduit, champ.value || 0);
        if (ok) {
            majPagePanier(donnees);
            annoncer('Panier mis à jour.');
        } else {
            annoncer(donnees.message ?? 'Modification impossible.', true);
            // On remet la quantité acceptée par le serveur
            const ligne = donnees.lignes?.find((l) => String(l.id_produit) === idProduit);
            if (ligne) champ.value = ligne.quantite;
        }
    }, 400);

    tableau.addEventListener('input', (evenement) => {
        const formulaire = evenement.target.closest('form[data-panier-quantite]');
        if (formulaire) modifier(evenement.target, formulaire.elements.id_produit.value);
    });
    tableau.addEventListener('submit', async (evenement) => {
        const formulaire = evenement.target;
        evenement.preventDefault();
        const idProduit = formulaire.elements.id_produit.value;
        const { ok, donnees } = formulaire.matches('[data-panier-retirer]')
            ? await operation('retirer', idProduit)
            : await operation('modifier', idProduit, formulaire.elements.quantite.value || 0);
        if (ok) {
            majPagePanier(donnees);
            annoncer('Panier mis à jour.');
        } else {
            annoncer(donnees.message ?? 'Modification impossible.', true);
        }
    });
}
