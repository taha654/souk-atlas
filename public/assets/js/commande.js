// =============================================================================
// Formulaire de commande :
//  - masque les champs de carte si « Paiement à la livraison » est choisi ;
//  - désactive le bouton après le premier clic (pas de double commande).
// Le serveur reste le seul juge : sans JS, tout est visible et tout est revérifié.
// =============================================================================
const formulaire = document.getElementById('formulaire-commande');
const champsCarte = document.getElementById('champs-carte');
const bouton = document.getElementById('bouton-payer');
const texteBouton = bouton.textContent;

function majModePaiement() {
    const carte = formulaire.elements.mode.value === 'CARTE';
    champsCarte.hidden = !carte;
    // Champs masqués = champs désactivés : ils ne sont pas envoyés
    for (const champ of champsCarte.querySelectorAll('input, select')) champ.disabled = !carte;
}

formulaire.addEventListener('change', (evenement) => {
    if (evenement.target.name === 'mode') majModePaiement();
});
majModePaiement();

formulaire.addEventListener('submit', () => {
    // Après un retour arrière, le bouton redevient actif (événement pageshow)
    bouton.disabled = true;
    bouton.textContent = 'Paiement en cours…';
});
window.addEventListener('pageshow', () => {
    bouton.disabled = false;
    bouton.textContent = texteBouton;
});
