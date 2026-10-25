// Repli des photos de démonstration : si /images/demo/produit-12-1.webp ne se
// charge pas, on affiche l'illustration /assets/img/produits/produit-12-1.svg.
// Même convention que app/Services/PhotosDemo.php.

const MOTIF = /^\/images\/demo\/((produit)-\d+-\d+|(annonce)-\d+)\.webp$/;

function illustration(chemin) {
    const m = MOTIF.exec(chemin);
    if (m === null) {
        return null;
    }
    return `/assets/img/${m[2] ? 'produits' : 'annonces'}/${m[1]}.svg`;
}

function remplacer(image) {
    const repli = illustration(new URL(image.src, location.href).pathname);
    if (repli !== null) {
        image.src = repli;   // un SVG manquant ne déclenche pas de boucle : il ne correspond plus au motif
    }
}

// L'événement "error" d'une image ne remonte pas jusqu'au document : on l'écoute
// en phase de capture. Cela couvre aussi les images ajoutées plus tard par le
// JavaScript (catalogue, galerie…).
document.addEventListener('error', (evenement) => {
    if (evenement.target instanceof HTMLImageElement) {
        remplacer(evenement.target);
    }
}, true);

// Un module s'exécute après l'analyse de la page : une image déjà en échec
// avant ce moment n'enverra plus d'événement
for (const image of document.images) {
    if (image.complete && image.naturalWidth === 0) {
        remplacer(image);
    }
}
