// =============================================================================
// Tests navigateur de l'étape 5 : tableau de bord vendeur (graphiques SVG) et
// gestion d'un produit avec photo. Comptes test-pw-… supprimés par lancer.sh.
// =============================================================================
import { test, expect } from '@playwright/test';

const CAPTURES = '../../docs/captures';
// PNG valide de 1 x 1 pixel
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');

test.beforeEach(async ({ page }) => {
    const erreurs = [];
    page.on('pageerror', (e) => erreurs.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error' && !m.text().includes('status of 422')) erreurs.push(m.text()); });
    test.info().erreursConsole = erreurs;
});
test.afterEach(async () => {
    expect(test.info().erreursConsole, 'erreurs dans la console du navigateur').toEqual([]);
});

async function connecter(page, email) {
    await page.goto('/connexion');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Mot de passe').fill('Demo1234!');
    await page.getByRole('button', { name: 'Se connecter' }).click();
}

test('tableau de bord : 3 graphiques SVG, période changée sans rechargement', async ({ page }) => {
    await connecter(page, 'youssef.benali@exemple.ma');
    await expect(page).toHaveURL(/\/vendeur$/);

    const jours = page.locator('#graphique-jours svg[role="img"]');
    await expect(jours).toBeVisible();
    await expect(page.locator('#graphique-mois svg rect.graphique__barre')).toHaveCount(12);
    await expect(page.locator('#graphique-produits svg rect.graphique__barre').first()).toBeVisible();
    // 30 jours : une barre par jour
    await expect(page.locator('#graphique-jours rect.graphique__barre')).toHaveCount(30);
    await expect(jours).toHaveAttribute('aria-label', /Chiffre d'affaires HT par jour sur 30 jours/);

    await page.evaluate(() => { window.__marqueur = true; });
    await page.getByLabel('Période').selectOption('90');
    await expect(page.locator('#libelle-periode')).toHaveText('90 derniers jours');
    // Au-delà d'un mois : une courbe plutôt que 90 barres
    await expect(page.locator('#graphique-jours path.graphique__ligne')).toHaveCount(1);
    await expect(page.locator('#graphique-jours circle.graphique__point')).toHaveCount(90);
    expect(await page.evaluate(() => window.__marqueur)).toBe(true);

    await page.setViewportSize({ width: 1280, height: 900 });
    await page.getByLabel('Période').selectOption('365');
    await expect(page.locator('#libelle-periode')).toHaveText('365 derniers jours');
    await page.screenshot({ path: `${CAPTURES}/etape5-tableau-de-bord.png`, fullPage: true });
});

test('nouveau vendeur : boutique, produit, photo, stock', async ({ page }) => {
    const email = `test-pw-vendeur-${Date.now()}@exemple.ma`;
    await page.goto('/inscription');
    await page.getByLabel('Vendeur professionnel : ouvrir une boutique').check();
    await page.getByLabel('Nom complet').fill('Vendeur Playwright');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Mot de passe', { exact: true }).fill('motdepasse1');
    await page.getByLabel('Confirmer le mot de passe').fill('motdepasse1');
    await page.getByRole('button', { name: 'Créer mon compte' }).click();

    await expect(page.getByRole('heading', { name: 'Ouvrir ma boutique' })).toBeVisible();
    await page.getByLabel('Nom de la boutique').fill(`Atelier PW ${Date.now()}`);
    await page.getByLabel('Ville').fill('Essaouira');
    await page.getByRole('button', { name: 'Créer ma boutique' }).click();
    await expect(page.getByText('Boutique créée.')).toBeVisible();
    await expect(page.getByText(/en attente de validation/)).toBeVisible();

    await page.getByRole('link', { name: 'Mes produits' }).click();
    await page.getByRole('link', { name: 'Nouveau produit' }).click();
    await page.getByLabel('Nom').fill('Panier en osier');
    await page.getByLabel('Catégorie').selectOption({ label: '— — Tapis & artisanat' });
    await page.getByLabel('Prix HT (MAD)').fill('250');
    await page.getByLabel('Stock initial').fill('8');
    await page.getByRole('button', { name: 'Créer le produit' }).click();
    await expect(page.getByText('Produit créé. Ajoutez-lui des photos.')).toBeVisible();

    await page.getByLabel(/Ajouter une photo/).setInputFiles({ name: 'osier.png', mimeType: 'image/png', buffer: PNG });
    await page.getByRole('button', { name: 'Envoyer' }).click();
    await expect(page.getByText('Photo ajoutée.')).toBeVisible();
    await expect(page.locator('.photos-vendeur img')).toHaveCount(1);
    await expect(page.getByRole('heading', { name: 'Photos (1/6)' })).toBeVisible();

    await page.getByLabel('Ajouter (+) ou retirer (−)').fill('-3');
    await page.getByRole('button', { name: 'Appliquer' }).click();
    await expect(page.getByRole('heading', { name: 'Stock : 5' })).toBeVisible();
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.screenshot({ path: `${CAPTURES}/etape5-produit.png`, fullPage: true });
});
