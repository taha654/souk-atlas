// =============================================================================
// Page d'accueil (étape 11) : vitrine des produits et des annonces.
// =============================================================================
import { test, expect } from '@playwright/test';
import { capturer } from './captures.js';


test.beforeEach(async ({ page }) => {
    const erreurs = [];
    page.on('pageerror', (erreur) => erreurs.push(erreur.message));
    page.on('console', (message) => { if (message.type() === 'error') erreurs.push(message.text()); });
    test.info().erreursConsole = erreurs;
});
test.afterEach(async () => {
    expect(test.info().erreursConsole, 'erreurs dans la console du navigateur').toEqual([]);
});

test('vitrine : 4 produits bien notés et 4 annonces récentes, liens vers les listes', async ({ page }) => {
    await page.goto('/');
    const produits = page.getByRole('region', { name: 'Les mieux notés' });
    const annonces = page.getByRole('region', { name: 'Dernières annonces d\'occasion' });
    await expect(produits.locator('.carte-produit')).toHaveCount(4);
    await expect(annonces.locator('.carte-produit')).toHaveCount(4);
    await expect(produits.locator('.carte-produit__stock').first()).not.toHaveText(/Épuisé/);
    await expect(page.getByText(/étapes? \d/)).toHaveCount(0);   // plus de texte de chantier
    await annonces.getByRole('link', { name: 'Toutes les annonces →' }).click();
    await expect(page).toHaveURL(/\/annonces$/);
});

test('captures d’écran de l’accueil pour le README', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto('/');
    await capturer(page, 'accueil.png');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');
    await capturer(page, 'accueil-mobile.png');
});
