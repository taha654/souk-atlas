// =============================================================================
// Tests navigateur de l'étape 9 : page « Jetons d'accès » (outil console C++).
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

test('un vendeur crée un jeton, le voit une fois, puis le révoque', async ({ page }) => {
    await page.goto('/connexion');
    await page.getByLabel('Email').fill('youssef.benali@exemple.ma');
    await page.getByLabel('Mot de passe').fill('Demo1234!');
    await page.getByRole('button', { name: 'Se connecter' }).click();

    await page.goto('/compte');
    await page.getByRole('link', { name: /Jetons d'accès/ }).click();
    await page.getByLabel('Nom du jeton').fill('test-capture');
    await page.getByLabel('Valable').selectOption('90');
    await page.getByRole('button', { name: 'Créer le jeton' }).click();

    const jeton = page.getByLabel('Votre jeton');
    await expect(jeton).toHaveValue(/^souk_[0-9a-f]{64}$/);
    const valeur = await jeton.inputValue();
    const ligne = page.getByRole('row', { name: /test-capture/ });
    await expect(ligne).toContainText('Valide');
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.screenshot({ path: `${CAPTURES}/etape9-jetons.png`, fullPage: true });

    // Rechargement : le jeton n'est plus jamais affiché
    await page.goto('/compte/jetons');
    await expect(page.getByLabel('Votre jeton')).toHaveCount(0);
    expect(await page.content()).not.toContain(valeur);

    page.once('dialog', (dialogue) => dialogue.accept());   // confirmation « Révoquer ce jeton ? »
    await page.getByRole('row', { name: /test-capture/ }).getByRole('button', { name: 'Révoquer' }).click();
    await expect(page.getByRole('row', { name: /test-capture/ })).toContainText('Révoqué');
});
