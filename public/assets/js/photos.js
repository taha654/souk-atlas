// =============================================================================
// Allègement des photos AVANT leur envoi (module WebAssembly, repli JavaScript).
//
// Une photo de téléphone (4000 × 3000 px, 5 Mo) est réduite à 1600 px au plus
// et réencodée : quelques centaines de Ko partent au lieu de plusieurs Mo.
// Bonus : le réencodage supprime les métadonnées EXIF (dont la position GPS
// où la photo a été prise), qu'on ne veut pas publier sur une annonce.
//
// Amélioration progressive : sans JavaScript, la photo part telle quelle et
// le serveur applique ses règles (5 Mo au plus) ; il revérifie TOUT de toute façon.
// =============================================================================
import { obtenirMoteur } from './wasm.js';

const COTE_MAX = 1600;          // pixels
const QUALITE_JPEG = 0.85;
const DEJA_LEGERE = 500 * 1024; // en dessous, et déjà petite, la photo part telle quelle

const octets = (n) => (n >= 1024 * 1024 ? `${(n / 1024 / 1024).toFixed(1).replace('.', ',')} Mo` : `${Math.round(n / 1024)} Ko`);

/** Le fichier allégé, ou null si l'original convient déjà */
async function alleger(fichier, moteur) {
    // imageOrientation : une photo prise "en portrait" garde le bon sens
    const image = await createImageBitmap(fichier, { imageOrientation: 'from-image' });
    try {
        const { largeur, hauteur } = moteur.dimensionsReduites(image.width, image.height, COTE_MAX);
        if (largeur === image.width && fichier.size <= DEJA_LEGERE) return null;

        // 1. Les pixels de la photo (RGBA) : on la dessine dans un canvas hors écran
        const source = new OffscreenCanvas(image.width, image.height);
        const ctxSource = source.getContext('2d');
        ctxSource.drawImage(image, 0, 0);
        const pixels = ctxSource.getImageData(0, 0, image.width, image.height).data;

        // 2. La réduction, par le C++ compilé en WebAssembly (ou le repli JS)
        const reduits = largeur === image.width ? pixels
            : moteur.reduireRgba(pixels, image.width, image.height, largeur, hauteur);

        // 3. L'encodage (JPEG, ou PNG pour garder la transparence) : fait par le navigateur
        const cible = new OffscreenCanvas(largeur, hauteur);
        cible.getContext('2d').putImageData(new ImageData(reduits, largeur, hauteur), 0, 0);
        const type = fichier.type === 'image/png' ? 'image/png' : 'image/jpeg';
        const blob = await cible.convertToBlob({ type, quality: QUALITE_JPEG });
        if (blob.size >= fichier.size) return null;   // rien gagné : on garde l'original
        const nom = fichier.name.replace(/\.[^.]*$/, '') + (type === 'image/png' ? '.png' : '.jpg');
        return new File([blob], nom, { type, lastModified: Date.now() });
    } finally {
        image.close();   // libère tout de suite la mémoire de l'image décodée
    }
}

function zoneMessage(champ) {
    let zone = champ.parentElement.querySelector('.photo-allegee');
    if (!zone) {
        zone = document.createElement('p');
        zone.className = 'photo-allegee';
        zone.setAttribute('aria-live', 'polite');   // annoncé par les lecteurs d'écran
        champ.insertAdjacentElement('afterend', zone);
    }
    return zone;
}

// Phase de CAPTURE : ce gestionnaire passe avant celui de validation.js (taille
// maximale). L'événement d'origine est arrêté ; un nouvel événement "change"
// est émis avec le fichier allégé, et c'est lui que validation.js contrôle.
document.addEventListener('change', async (evenement) => {
    const champ = evenement.target;
    if (!(champ instanceof HTMLInputElement) || !champ.matches('input[type="file"][data-alleger]')) return;
    if (champ.dataset.allegee === 'oui') {   // notre propre événement : on le laisse passer
        delete champ.dataset.allegee;
        return;
    }
    const fichier = champ.files[0];
    if (!fichier || !fichier.type.startsWith('image/')) return;
    evenement.stopImmediatePropagation();

    const zone = zoneMessage(champ);
    const bouton = champ.form?.querySelector('button[type="submit"]');
    if (bouton) bouton.disabled = true;
    zone.textContent = 'Préparation de la photo…';
    try {
        const moteur = await obtenirMoteur();
        const debut = performance.now();
        const allegee = await alleger(fichier, moteur);
        if (allegee) {
            // DataTransfer : seule façon de remplacer le fichier choisi dans un <input type="file">
            const transfert = new DataTransfer();
            transfert.items.add(allegee);
            champ.files = transfert.files;
            zone.textContent = `Photo allégée : ${octets(fichier.size)} → ${octets(allegee.size)} `
                + `(${moteur.nom}, ${Math.round(performance.now() - debut)} ms).`;
            zone.dataset.moteur = moteur.nom;
        } else {
            zone.textContent = 'Photo déjà légère : envoyée telle quelle.';
        }
    } catch (erreur) {
        // Format que le navigateur ne sait pas décoder (HEIC…) : on laisse le serveur juger
        zone.textContent = 'La photo n\'a pas pu être allégée ; elle sera envoyée telle quelle.';
        console.warn(erreur);
    } finally {
        if (bouton) bouton.disabled = false;
        champ.dataset.allegee = 'oui';
        champ.dispatchEvent(new Event('change', { bubbles: true }));
    }
}, true);
