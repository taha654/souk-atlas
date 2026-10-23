// =============================================================================
// Appels à l'API JSON du site (module ES partagé).
// =============================================================================

/**
 * GET JSON. Lève une erreur si le serveur répond autre chose qu'un 2xx.
 * `signal` (AbortController) permet d'annuler la requête : utile quand
 * l'utilisateur change de filtre avant que la réponse précédente n'arrive.
 */
export async function getJson(url, { signal } = {}) {
    const reponse = await fetch(url, {
        headers: { Accept: 'application/json' },
        signal,
    });
    if (!reponse.ok) {
        throw new Error(`Erreur ${reponse.status} pour ${url}`);
    }
    return reponse.json();
}

/**
 * Retarde l'appel de `fonction` jusqu'à ce que `delai` ms se soient écoulées
 * sans nouvel appel (debounce). Taper "samsung" n'envoie qu'une requête,
 * pas sept (une par lettre).
 */
export function debounce(fonction, delai) {
    let minuterie = null;
    return (...args) => {
        clearTimeout(minuterie);
        minuterie = setTimeout(() => fonction(...args), delai);
    };
}

/** Vrai si l'erreur vient d'une requête annulée volontairement (AbortController) */
export function estAnnulation(erreur) {
    return erreur instanceof DOMException && erreur.name === 'AbortError';
}
