// =============================================================================
// Captures d'écran pour le README et docs/captures/.
// Elles ne sont prises QUE si on le demande (CAPTURES=1) : sinon chaque
// lancement des tests modifierait les images versionnées (dates, jetons…).
//   CAPTURES=1 ./tests/navigateur/lancer.sh
// =============================================================================
const DOSSIER = '../../docs/captures';

export const capturesDemandees = process.env.CAPTURES === '1';

/** page.screenshot(), seulement si CAPTURES=1 ; nom : "accueil.png" */
export async function capturer(page, nom, options = {}) {
    if (!capturesDemandees) return;
    await page.screenshot({ ...options, path: `${DOSSIER}/${nom}` });
}
