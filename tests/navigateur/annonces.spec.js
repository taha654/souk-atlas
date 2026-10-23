// =============================================================================
// Tests navigateur de l'étape 6 : annonces et messagerie en "temps réel" (polling).
// Deux contextes de navigateur = deux personnes sur deux ordinateurs.
// =============================================================================
import { test, expect } from '@playwright/test';
import { capturer } from './captures.js';


async function connecter(page, email) {
    await page.goto('/connexion');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Mot de passe').fill('Demo1234!');
    await page.getByRole('button', { name: 'Se connecter' }).click();
}

test('filtres des annonces et fiche', async ({ page }) => {
    await page.goto('/annonces');
    await page.getByLabel('Catégorie').selectOption({ label: 'Véhicules' });
    await expect(page).toHaveURL(/categorie=29/);   // envoi automatique au changement
    const cartes = page.locator('.grille-produits .carte-produit');
    await expect(cartes.first()).toBeVisible();
    await page.getByLabel('Trier').selectOption('prix_desc');
    await expect(page).toHaveURL(/tri=prix_desc/);
    await page.setViewportSize({ width: 1280, height: 900 });
    await capturer(page, 'etape6-annonces.png', { fullPage: true });

    await cartes.first().click();
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Se connecter pour contacter le vendeur' })).toBeVisible();
    await capturer(page, 'etape6-fiche-annonce.png', { fullPage: true });
});

test('messagerie : le message apparaît chez l’autre sans rechargement', async ({ browser }) => {
    // Fatima Zahra a écrit à Amine au sujet de son iPhone 12 (données de démo)
    const amine = await (await browser.newContext()).newPage();
    const fatima = await (await browser.newContext()).newPage();
    await connecter(amine, 'amine.lahlou@exemple.ma');
    await connecter(fatima, 'fatimazahra.bennani@exemple.ma');

    await fatima.goto('/messages');
    await fatima.getByRole('link', { name: /iPhone 12/ }).click();
    await amine.goto(fatima.url().replace(/^.*\/messages\//, '/messages/'));
    await amine.evaluate(() => { window.__marqueur = true; });

    const texte = 'Rendez-vous demain à 18 h devant la gare ?';
    await fatima.getByLabel('Votre message').fill(texte);
    await fatima.getByRole('button', { name: 'Envoyer' }).click();
    // Chez l'expéditrice : affiché tout de suite
    await expect(fatima.locator('#fil-messages .message--moi').last()).toContainText(texte);
    await expect(fatima.getByLabel('Votre message')).toHaveValue('');

    // Chez le destinataire : arrivé par le polling (toutes les 5 s), sans rechargement
    await expect(amine.locator('#fil-messages .message').last()).toContainText(texte, { timeout: 12_000 });
    expect(await amine.evaluate(() => window.__marqueur)).toBe(true);
    await amine.setViewportSize({ width: 1280, height: 900 });
    await capturer(amine, 'etape6-messagerie.png', { fullPage: true });
    // Ce message est supprimé à la fin par lancer.sh (messages créés pendant les tests)
});
