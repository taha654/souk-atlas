// =============================================================================
// Validation des formulaires côté client (module ES).
//
// C'est un CONFORT pour l'utilisateur (erreur affichée sans attendre le
// serveur), jamais une sécurité : n'importe qui peut désactiver JavaScript ou
// envoyer une requête à la main. Le serveur revalide tout (Utilisateur::validerInscription).
//
// S'applique aux formulaires marqués data-valider. Utilise les attributs HTML
// déjà présents (required, minlength, type="email") + data-identique-a.
// =============================================================================

const MESSAGES = {
    valueMissing: 'Ce champ est obligatoire.',
    typeMismatch: 'Adresse email invalide.',
    tooShort: (champ) => `Au moins ${champ.minLength} caractères.`,
};

/** Message d'erreur du champ, ou chaîne vide s'il est valide */
function messagePour(champ) {
    const etat = champ.validity;
    if (etat.valueMissing) return MESSAGES.valueMissing;
    if (etat.typeMismatch) return MESSAGES.typeMismatch;
    // tooShort n'est signalé par le navigateur qu'après une saisie : on vérifie nous-mêmes
    if (champ.minLength > 0 && champ.value.length > 0 && champ.value.length < champ.minLength) {
        return MESSAGES.tooShort(champ);
    }
    const reference = champ.dataset.identiqueA;
    if (reference && champ.value !== champ.form.elements[reference].value) {
        return 'Les deux mots de passe ne correspondent pas.';
    }
    return '';
}

/** Affiche (ou retire) le message sous le champ, de façon accessible */
function afficher(champ, message) {
    const id = `erreur-js-${champ.name}`;
    let zone = document.getElementById(id);
    if (!zone) {
        zone = document.createElement('p');
        zone.id = id;
        zone.className = 'champ__erreur';
        // aria-live : les lecteurs d'écran annoncent le message quand il change
        zone.setAttribute('aria-live', 'polite');
        champ.insertAdjacentElement('afterend', zone);
    }
    zone.textContent = message; // textContent, pas innerHTML : aucun HTML injecté
    champ.setAttribute('aria-invalid', message ? 'true' : 'false');
    const decrits = (champ.getAttribute('aria-describedby') || '').split(' ').filter((x) => x && x !== id);
    if (message) decrits.push(id);
    champ.setAttribute('aria-describedby', decrits.join(' '));
}

function brancher(formulaire) {
    const champs = [...formulaire.querySelectorAll('input:not([type="hidden"]):not([type="radio"])')];

    // Vérification quand on quitte un champ, puis à chaque frappe une fois une erreur affichée
    for (const champ of champs) {
        champ.addEventListener('blur', () => afficher(champ, messagePour(champ)));
        champ.addEventListener('input', () => {
            if (champ.getAttribute('aria-invalid') === 'true') afficher(champ, messagePour(champ));
        });
    }

    formulaire.addEventListener('submit', (evenement) => {
        let premierInvalide = null;
        for (const champ of champs) {
            const message = messagePour(champ);
            afficher(champ, message);
            if (message && !premierInvalide) premierInvalide = champ;
        }
        if (premierInvalide) {
            evenement.preventDefault();
            premierInvalide.focus();
        }
    });
}

document.querySelectorAll('form[data-valider]').forEach(brancher);

// Taille maximale d'un fichier (data-taille-max, en octets) : l'utilisateur
// est prévenu AVANT d'attendre l'envoi d'une photo trop lourde. Le serveur
// revérifie (app/Services/Upload.php).
for (const champ of document.querySelectorAll('input[type="file"][data-taille-max]')) {
    champ.addEventListener('change', () => {
        const fichier = champ.files[0];
        const trop = fichier && fichier.size > Number(champ.dataset.tailleMax);
        champ.setCustomValidity(trop ? 'Photo trop lourde : 5 Mo au maximum.' : '');
        champ.reportValidity();
    });
}
