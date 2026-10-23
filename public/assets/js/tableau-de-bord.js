// =============================================================================
// Tableau de bord vendeur : graphiques SVG et changement de période sans
// rechargement (fetch /api/vendeur/statistiques?jours=…).
// Sans JavaScript, la page affiche déjà les chiffres et les tableaux de données.
// =============================================================================
import { getJson } from './api.js';
import { barres, barresHorizontales, courbe } from './graphiques.js';

const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const prix = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'MAD', maximumFractionDigits: 0 });
const formatPrix = (valeur) => prix.format(valeur);

const choixPeriode = document.getElementById('periode');

function dessiner(stats) {
    const jours = stats.par_jour;
    // Au-delà d'un mois, une étiquette sur 7 (sinon les dates se chevauchent)
    const etiquetteChaque = jours.length > 31 ? Math.ceil(jours.length / 12) : (jours.length > 15 ? 2 : 1);
    const donneesJours = jours.map((j) => ({
        libelle: `${j.jour.slice(8, 10)}/${j.jour.slice(5, 7)}`,
        valeur: j.ca_ht,
        detail: `${j.nb_commandes} commande(s)`,
    }));
    const totalPeriode = jours.reduce((somme, j) => somme + j.ca_ht, 0);
    const dessinJours = jours.length > 31 ? courbe : barres;
    dessinJours(document.getElementById('graphique-jours'), donneesJours, {
        titre: `Chiffre d'affaires HT par jour sur ${stats.jours} jours : ${formatPrix(totalPeriode)} au total`,
        format: formatPrix, etiquetteChaque, largeur: 1000,   // graphique pleine largeur
    });

    barres(document.getElementById('graphique-mois'),
        stats.par_mois.map((m) => ({ libelle: MOIS[m.mois - 1], valeur: m.ca_ht,
            detail: m.evolution_pct === null ? '' : `${m.evolution_pct > 0 ? '+' : ''}${m.evolution_pct} % sur un mois` })),
        { titre: "Chiffre d'affaires HT par mois de l'année en cours", format: formatPrix });

    barresHorizontales(document.getElementById('graphique-produits'),
        stats.meilleures_ventes.map((v) => ({ libelle: v.nom, valeur: v.quantite })),
        { titre: `Meilleures ventes sur ${stats.jours} jours, en quantités`, format: (q) => `${q} vendu(s)` });
}

function majTuiles(resume) {
    const tuile = (nom) => document.querySelector(`[data-tuile="${nom}"]`);
    tuile('ca_ht').textContent = formatPrix(resume.ca_ht);
    tuile('nb_commandes').textContent = String(resume.nb_commandes);
    tuile('articles_vendus').textContent = String(resume.articles_vendus);
    tuile('panier_moyen').textContent = formatPrix(resume.panier_moyen);
}

async function charger(jours) {
    const stats = await getJson(`/api/vendeur/statistiques?jours=${jours}`);
    dessiner(stats);
    majTuiles(stats.resume);
    document.getElementById('libelle-periode').textContent = `${stats.jours} derniers jours`;
}

// Le sélecteur n'a de sens qu'avec JavaScript : on l'affiche seulement maintenant
choixPeriode.hidden = false;
choixPeriode.addEventListener('change', () => charger(choixPeriode.value));
charger(choixPeriode.value);
