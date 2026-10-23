// =============================================================================
// Tests navigateur de l'étape 4 : panier dynamique et parcours d'achat complet.
// Les comptes créés (test-pw-…@exemple.ma) sont supprimés par lancer.sh.
// =============================================================================
import { test, expect } from '@playwright/test';
import { capturer } from './captures.js';


test.beforeEach(async ({ page }) => {
    const erreurs = [];
    page.on('pageerror', (e) => erreurs.push(e.message));
    page.on('console', (m) => {
        // Un formulaire refusé (carte invalide…) revient volontairement en 422 :
        // Chrome le signale dans la console, ce n'est pas une erreur de la page
        if (m.type() === 'error' && !m.text().includes('status of 422')) erreurs.push(m.text());
    });
    test.info().erreursConsole = erreurs;
});
test.afterEach(async () => {
    expect(test.info().erreursConsole, 'erreurs dans la console du navigateur').toEqual([]);
});

test('ajout au panier sans rechargement : le badge se met à jour', async ({ page }) => {
    await page.goto('/produit/30');
    await page.evaluate(() => { window.__marqueur = true; });
    const badge = page.locator('#badge-panier');
    await expect(badge).toBeHidden();

    await page.getByLabel('Quantité').fill('2');
    await page.getByRole('button', { name: 'Ajouter au panier' }).click();

    await expect(page.locator('#message-panier')).toHaveText('Ajouté au panier.');
    await expect(badge).toHaveText('2');
    expect(await page.evaluate(() => window.__marqueur)).toBe(true);
});

test('page panier : quantité et retrait mis à jour sans rechargement', async ({ page }) => {
    await page.goto('/produit/30');
    await page.getByRole('button', { name: 'Ajouter au panier' }).click();
    await expect(page.locator('#badge-panier')).toHaveText('1');
    await page.goto('/produit/44');
    await page.getByRole('button', { name: 'Ajouter au panier' }).click();
    await expect(page.locator('#badge-panier')).toHaveText('2');

    await page.goto('/panier');
    await page.evaluate(() => { window.__marqueur = true; });
    const totalAvant = await page.locator('[data-total="ttc"]').textContent();

    await page.getByLabel('Quantité de Coussins en kilim (lot de 2)').fill('3');
    await expect(page.locator('#badge-panier')).toHaveText('4');
    await expect(page.locator('[data-total="ttc"]')).not.toHaveText(totalAvant);

    await page.getByRole('button', { name: /Retirer\s+Huile d'argan/ }).click();
    await expect(page.locator('tr[data-ligne]')).toHaveCount(1);
    await expect(page.locator('#badge-panier')).toHaveText('3');
    // Pas de bouton « Mettre à jour » avec JavaScript : la quantité suffit
    await expect(page.getByRole('button', { name: 'Mettre à jour' })).toBeHidden();
    expect(await page.evaluate(() => window.__marqueur)).toBe(true);

    await page.setViewportSize({ width: 1280, height: 800 });
    await capturer(page, 'etape4-panier.png', { fullPage: true });
});

test('parcours complet : panier, inscription, paiement, confirmation, facture, suivi', async ({ page }) => {
    const email = `test-pw-${Date.now()}@exemple.ma`;

    // 1. Panier rempli en visiteur
    await page.goto('/produit/30');
    await page.getByRole('button', { name: 'Ajouter au panier' }).click();
    await expect(page.locator('#badge-panier')).toHaveText('1');

    // 2. Commander exige un compte ; le panier survit à l'inscription
    await page.goto('/panier');
    await page.getByRole('link', { name: 'Se connecter pour commander' }).click();
    await expect(page).toHaveURL(/\/connexion\?retour=%2Fcommande/);
    await page.getByRole('link', { name: 'Créer un compte' }).first().click();
    await page.getByLabel('Nom complet').fill('Test Playwright');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Mot de passe', { exact: true }).fill('motdepasse1');
    await page.getByLabel('Confirmer le mot de passe').fill('motdepasse1');
    await page.getByRole('button', { name: 'Créer mon compte' }).click();
    await expect(page.locator('#badge-panier')).toHaveText('1');

    // 3. Formulaire : les champs de carte disparaissent pour un paiement à la livraison
    await page.goto('/commande');
    const champsCarte = page.locator('#champs-carte');
    await expect(champsCarte).toBeVisible();
    await page.getByLabel('Paiement à la livraison (espèces)').check();
    await expect(champsCarte).toBeHidden();
    await page.getByLabel('Carte bancaire', { exact: true }).check();
    await expect(champsCarte).toBeVisible();

    await page.getByLabel('Adresse', { exact: true }).fill('12 rue des Orangers');
    await page.getByLabel('Ville').fill('Rabat');
    await page.getByLabel('Téléphone (pour le livreur)').fill('06 12 34 56 78');

    // 4. Carte refusée : message sur place, numéro NON réaffiché
    await page.getByLabel('Numéro de carte').fill('4111 1111 1111 1112');
    await page.getByLabel('Mois').selectOption('12');
    await page.getByLabel('Année').selectOption(String(new Date().getFullYear() + 2));
    await page.getByLabel('Cryptogramme').fill('123');
    await page.getByRole('button', { name: /Confirmer et payer/ }).click();
    await expect(page.getByText('Numéro de carte invalide.')).toBeVisible();
    await expect(page.getByLabel('Numéro de carte')).toHaveValue('');
    await expect(page.getByLabel('Adresse', { exact: true })).toHaveValue('12 rue des Orangers');

    // 5. Paiement accepté
    await page.getByLabel('Numéro de carte').fill('4111 1111 1111 1111');
    await page.getByLabel('Mois').selectOption('12');
    await page.getByLabel('Année').selectOption(String(new Date().getFullYear() + 2));
    await page.getByLabel('Cryptogramme').fill('123');
    await page.setViewportSize({ width: 1280, height: 900 });
    await capturer(page, 'etape4-commande.png', { fullPage: true });
    const bouton = page.getByRole('button', { name: /Confirmer et payer/ });
    await bouton.click();

    await expect(page).toHaveURL(/\/achat\/ACH-\d{4}-\d{6}$/);
    await expect(page.getByText('Merci ! Votre commande est enregistrée.')).toBeVisible();
    await expect(page.getByText('carte bancaire se terminant par 1111')).toBeVisible();
    await expect(page.locator('#badge-panier')).toBeHidden();

    // 6. Facture imprimable
    await page.getByRole('link', { name: 'Voir la facture' }).click();
    await expect(page.getByRole('heading', { name: 'Facture' })).toBeVisible();
    await expect(page.locator('.entete')).toHaveCount(0); // layout d'impression : pas de menu
    await capturer(page, 'etape4-facture.png', { fullPage: true });
    await page.emulateMedia({ media: 'print' });
    await expect(page.locator('.ecran-seulement')).toBeHidden();
    await page.emulateMedia({ media: 'screen' });

    // 7. Suivi
    await page.goto('/mes-commandes');
    await page.locator('.liste-achats a[href^="/commande/"]').first().click();
    await expect(page.locator('[aria-current="step"]')).toContainText('Payée');
    await capturer(page, 'etape4-suivi.png', { fullPage: true });

    // 8. Annulation (confirmation demandée)
    page.once('dialog', (dialogue) => dialogue.accept());
    await page.getByRole('button', { name: 'Annuler la commande' }).click();
    await expect(page.getByText(/Commande annulée\. Les articles sont remis en stock/)).toBeVisible();
});
