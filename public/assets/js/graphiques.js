// =============================================================================
// Petits graphiques SVG faits main (aucune bibliothèque).
//
// Un graphique SVG n'est qu'un dessin vectoriel : des <rect> pour les barres,
// un <path> pour une courbe, des <text> pour les étiquettes. On calcule soi-même
// les coordonnées : valeur → hauteur en pixels (une simple règle de trois).
//
// Accessibilité : le <svg> porte role="img" et un aria-label qui résume les
// données ; chaque barre/point a un <title> (info-bulle au survol). Les données
// complètes restent disponibles dans le tableau "Voir les données" de la page.
// =============================================================================

const SVG = 'http://www.w3.org/2000/svg';
// Dimensions du dessin en "unités SVG" ; le navigateur met ensuite à l'échelle
// (viewBox). Un graphique pleine largeur reçoit une largeur plus grande pour que
// le texte garde à peu près la même taille à l'écran.
const LARGEUR_DEFAUT = 600;
const HAUTEUR = 260;
const MARGE = { haut: 16, droite: 12, bas: 36, gauche: 64 };

/** Crée un élément SVG avec ses attributs */
function el(nom, attributs = {}, texte = null) {
    const element = document.createElementNS(SVG, nom);
    for (const [cle, valeur] of Object.entries(attributs)) element.setAttribute(cle, valeur);
    if (texte !== null) element.textContent = texte;
    return element;
}

/**
 * Maximum "rond" pour l'axe : 8 734 → 10 000, 1 240 → 2 000.
 * On arrondit au multiple supérieur de 1, 2 ou 5 × une puissance de 10.
 */
export function maximumRond(valeur) {
    if (valeur <= 0) return 1;
    const puissance = 10 ** Math.floor(Math.log10(valeur));
    for (const facteur of [1, 2, 5, 10]) {
        if (valeur <= facteur * puissance) return facteur * puissance;
    }
    return 10 * puissance;
}

const formatCourt = new Intl.NumberFormat('fr-FR', { notation: 'compact', maximumFractionDigits: 1 });

/** Cadre commun : <svg>, graduations horizontales et axe des valeurs */
function cadre(conteneur, titre, maximum, LARGEUR) {
    const svg = el('svg', {
        viewBox: `0 0 ${LARGEUR} ${HAUTEUR}`, role: 'img', 'aria-label': titre, class: 'graphique__svg',
    });
    const hauteurUtile = HAUTEUR - MARGE.haut - MARGE.bas;
    for (let i = 0; i <= 4; i++) {
        const valeur = (maximum / 4) * i;
        const y = MARGE.haut + hauteurUtile - (valeur / maximum) * hauteurUtile;
        svg.append(
            el('line', { x1: MARGE.gauche, x2: LARGEUR - MARGE.droite, y1: y, y2: y, class: 'graphique__grille' }),
            el('text', { x: MARGE.gauche - 8, y: y + 4, 'text-anchor': 'end', class: 'graphique__axe' }, formatCourt.format(valeur)),
        );
    }
    conteneur.replaceChildren(svg);
    return { svg, hauteurUtile, largeurUtile: LARGEUR - MARGE.gauche - MARGE.droite };
}

/**
 * Barres verticales.
 * @param {HTMLElement} conteneur
 * @param {{libelle: string, valeur: number, detail?: string}[]} donnees
 */
export function barres(conteneur, donnees, { titre, format = String, etiquetteChaque = 1, largeur = LARGEUR_DEFAUT } = {}) {
    const maximum = maximumRond(Math.max(...donnees.map((d) => d.valeur), 0));
    const { svg, hauteurUtile, largeurUtile } = cadre(conteneur, titre, maximum, largeur);
    const pas = largeurUtile / donnees.length;
    const largeurBarre = Math.max(2, pas * 0.7);

    donnees.forEach((d, i) => {
        const hauteur = (d.valeur / maximum) * hauteurUtile;
        const x = MARGE.gauche + i * pas + (pas - largeurBarre) / 2;
        const barre = el('rect', {
            x, y: MARGE.haut + hauteurUtile - hauteur, width: largeurBarre, height: hauteur, rx: 2, class: 'graphique__barre',
        });
        barre.append(el('title', {}, `${d.libelle} : ${format(d.valeur)}${d.detail ? ' — ' + d.detail : ''}`));
        svg.append(barre);
        if (i % etiquetteChaque === 0) {
            svg.append(el('text', { x: x + largeurBarre / 2, y: HAUTEUR - MARGE.bas + 16, 'text-anchor': 'middle',
                class: 'graphique__axe' }, d.libelle));
        }
    });
}

/** Barres horizontales (classements : le libellé long tient à gauche) */
export function barresHorizontales(conteneur, donnees, { titre, format = String, largeur = LARGEUR_DEFAUT } = {}) {
    const LARGEUR = largeur;
    const hauteurLigne = 34;
    const hauteur = Math.max(1, donnees.length) * hauteurLigne + 8;
    const maximum = Math.max(...donnees.map((d) => d.valeur), 1);
    const debut = 220;   // place réservée aux noms de produits
    const svg = el('svg', { viewBox: `0 0 ${LARGEUR} ${hauteur}`, role: 'img', 'aria-label': titre, class: 'graphique__svg' });

    donnees.forEach((d, i) => {
        const y = 4 + i * hauteurLigne;
        const largeur = (d.valeur / maximum) * (LARGEUR - debut - 95);   // place pour « 35 vendu(s) »
        const nom = d.libelle.length > 24 ? d.libelle.slice(0, 23) + '…' : d.libelle;
        const barre = el('rect', { x: debut, y: y + 6, width: Math.max(largeur, 2), height: hauteurLigne - 14, rx: 3, class: 'graphique__barre' });
        barre.append(el('title', {}, `${d.libelle} : ${format(d.valeur)}`));
        svg.append(
            el('text', { x: debut - 8, y: y + hauteurLigne / 2 + 4, 'text-anchor': 'end', class: 'graphique__libelle' }, nom),
            barre,
            el('text', { x: debut + largeur + 6, y: y + hauteurLigne / 2 + 4, class: 'graphique__axe' }, format(d.valeur)),
        );
    });
    if (donnees.length === 0) {
        svg.append(el('text', { x: LARGEUR / 2, y: hauteur / 2 + 4, 'text-anchor': 'middle', class: 'graphique__axe' }, 'Aucune vente sur la période'));
    }
    conteneur.replaceChildren(svg);
}

/** Courbe (évolution dans le temps), avec une aire légère sous la ligne */
export function courbe(conteneur, donnees, { titre, format = String, etiquetteChaque = 1, largeur = LARGEUR_DEFAUT } = {}) {
    const maximum = maximumRond(Math.max(...donnees.map((d) => d.valeur), 0));
    const { svg, hauteurUtile, largeurUtile } = cadre(conteneur, titre, maximum, largeur);
    const pas = donnees.length > 1 ? largeurUtile / (donnees.length - 1) : 0;
    const points = donnees.map((d, i) => [MARGE.gauche + i * pas, MARGE.haut + hauteurUtile - (d.valeur / maximum) * hauteurUtile]);
    const ligne = points.map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
    const bas = MARGE.haut + hauteurUtile;

    if (points.length > 0) {
        svg.append(
            el('path', { d: `${ligne} L${points.at(-1)[0]},${bas} L${points[0][0]},${bas} Z`, class: 'graphique__aire' }),
            el('path', { d: ligne, class: 'graphique__ligne' }),
        );
    }
    donnees.forEach((d, i) => {
        const [x, y] = points[i];
        const point = el('circle', { cx: x, cy: y, r: 3.5, class: 'graphique__point' });
        point.append(el('title', {}, `${d.libelle} : ${format(d.valeur)}${d.detail ? ' — ' + d.detail : ''}`));
        svg.append(point);
        if (i % etiquetteChaque === 0) {
            svg.append(el('text', { x, y: HAUTEUR - MARGE.bas + 16, 'text-anchor': 'middle', class: 'graphique__axe' }, d.libelle));
        }
    });
}
