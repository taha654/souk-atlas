// =============================================================================
// Demande une confirmation avant d'envoyer un formulaire marqué data-confirmer
// (ex. annuler une commande). Le message est celui de l'attribut.
// Un écouteur JavaScript plutôt qu'un onsubmit="…" dans le HTML : la politique
// de sécurité du site (CSP) interdit le JavaScript écrit dans les attributs.
// =============================================================================
document.addEventListener('submit', (evenement) => {
    const formulaire = evenement.target.closest('form[data-confirmer]');
    if (formulaire && !window.confirm(formulaire.dataset.confirmer)) {
        evenement.preventDefault();
    }
});
