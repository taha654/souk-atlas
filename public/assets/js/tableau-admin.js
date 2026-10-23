// =============================================================================
// Tableau de bord administrateur : graphiques SVG (graphiques.js) et période
// modifiable sans rechargement (fetch /api/admin/statistiques?jours=…).
// =============================================================================
import { getJson } from './api.js';
import { barres, barresHorizontales, courbe } from './graphiques.js';

const prix = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'MAD', maximumFractionDigits: 0 });
const choix = document.getElementById('periode');

function dessiner(stats) {
    const jours = stats.par_jour.map((j) => ({ libelle: `${j.jour.slice(8, 10)}/${j.jour.slice(5, 7)}`, valeur: j.ca_ht,
        detail: `${j.nb_commandes} commande(s)` }));
    const etiquetteChaque = jours.length > 31 ? Math.ceil(jours.length / 12) : (jours.length > 15 ? 2 : 1);
    (jours.length > 31 ? courbe : barres)(document.getElementById('graphique-jours'), jours, {
        titre: `Chiffre d'affaires HT par jour sur ${stats.jours} jours`, format: (v) => prix.format(v), etiquetteChaque, largeur: 1000,
    });
    barresHorizontales(document.getElementById('graphique-vendeurs'),
        stats.par_vendeur.map((v) => ({ libelle: `${v.rang}. ${v.boutique}`, valeur: v.ca_ht })),
        { titre: `Classement des boutiques sur ${stats.jours} jours`, format: (v) => prix.format(v), largeur: 1000 });
    document.getElementById('panier-moyen').textContent = prix.format(stats.panier_moyen);
    document.getElementById('libelle-periode').textContent = `${stats.jours} derniers jours`;
}

choix.hidden = false;
choix.addEventListener('change', async () => dessiner(await getJson(`/api/admin/statistiques?jours=${choix.value}`)));
getJson(`/api/admin/statistiques?jours=${choix.value}`).then(dessiner);
