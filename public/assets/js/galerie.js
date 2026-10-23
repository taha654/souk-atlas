// =============================================================================
// Galerie photos d'une fiche produit (et plus tard d'une annonce).
//
// Les vignettes sont des <button> : focusables et activables au clavier
// (Entrée, Espace) sans code en plus. On ajoute ← → pour passer d'une
// vignette à l'autre, et aria-pressed indique la photo affichée.
// =============================================================================

for (const galerie of document.querySelectorAll('[data-galerie]')) {
    const image = galerie.querySelector('[data-galerie-image]');
    const vignettes = [...galerie.querySelectorAll('.galerie__vignette')];

    const montrer = (index) => {
        const vignette = vignettes[index];
        image.src = vignette.dataset.src;
        image.alt = vignette.dataset.alt;
        vignettes.forEach((v, i) => v.setAttribute('aria-pressed', String(i === index)));
    };

    vignettes.forEach((vignette, index) => {
        vignette.addEventListener('click', () => montrer(index));
        vignette.addEventListener('keydown', (evenement) => {
            const decalage = { ArrowRight: 1, ArrowLeft: -1 }[evenement.key];
            if (decalage === undefined) return;
            evenement.preventDefault();
            // Modulo : depuis la dernière photo, → revient à la première
            const suivant = (index + decalage + vignettes.length) % vignettes.length;
            vignettes[suivant].focus();
            montrer(suivant);
        });
    });
}
