// =============================================================================
// Filtres des annonces : envoi automatique du formulaire (GET) à chaque
// changement. Les filtres restent dans l'URL, donc la page reste partageable.
// Les listes et cases s'appliquent tout de suite ; la saisie attend une pause.
// =============================================================================
import { debounce } from './api.js';

const formulaire = document.getElementById('filtres-annonces');
const envoyer = () => formulaire.requestSubmit();
const envoyerApresPause = debounce(envoyer, 700);

formulaire.addEventListener('change', (evenement) => {
    if (evenement.target.matches('select')) envoyer();
});
formulaire.addEventListener('input', (evenement) => {
    if (evenement.target.matches('input')) envoyerApresPause();
});
