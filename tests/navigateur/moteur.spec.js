// =============================================================================
// Tests navigateur de l'étape 8 : résultats du moteur C++ visibles sur le site.
// Critère : « Les recommandations s'affichent sur la fiche produit ».
// =============================================================================
import { test, expect } from '@playwright/test';

const CAPTURES = '../../docs/captures';

test.beforeEach(async ({ page }) => {
    const erreurs = [];
    page.on('pageerror', (erreur) => erreurs.push(erreur.message));
    page.on('console', (message) => { if (message.type() === 'error') erreurs.push(message.text()); });
    test.info().erreursConsole = erreurs;
});
test.afterEach(async () => {
    expect(test.info().erreursConsole, 'erreurs dans la console du navigateur').toEqual([]);
});

test('« Souvent achetés ensemble » : cartes affichées et cliquables', async ({ page }) => {
    await page.goto('/produit/1');
    const section = page.getByRole('region', { name: 'Souvent achetés ensemble' });
    await expect(section).toBeVisible();
    const cartes = section.locator('.carte-produit');
    expect(await cartes.count()).toBeGreaterThanOrEqual(1);
    expect(await cartes.count()).toBeLessThanOrEqual(4);

    // Le produit recommandé recommande à son tour le produit de départ (relation symétrique)
    const nom = await cartes.first().locator('.carte-produit__nom').innerText();
    await cartes.first().locator('a').click();
    await expect(page.getByRole('heading', { level: 1 })).toHaveText(nom);
    await expect(page.getByRole('region', { name: 'Souvent achetés ensemble' }).locator('a[href="/produit/1"]')).toHaveCount(1);
});

test('capture d’écran pour le portfolio', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto('/produit/1');
    await page.getByRole('region', { name: 'Souvent achetés ensemble' }).scrollIntoViewIfNeeded();
    await page.screenshot({ path: `${CAPTURES}/etape8-recommandations.png` });
});
