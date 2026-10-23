// =============================================================================
// Tests navigateur de l'étape 7 : un signalement traité de bout en bout, par
// l'interface (3 personnes : l'auteur, celui qui signale, l'administrateur).
// Comptes test-pw-… et leurs annonces supprimés par lancer.sh.
// =============================================================================
import { test, expect } from '@playwright/test';

const CAPTURES = '../../docs/captures';

async function inscrire(page, email) {
    await page.goto('/inscription');
    await page.getByLabel('Nom complet').fill('Membre Playwright');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Mot de passe', { exact: true }).fill('motdepasse1');
    await page.getByLabel('Confirmer le mot de passe').fill('motdepasse1');
    await page.getByRole('button', { name: 'Créer mon compte' }).click();
}

test('signalement traité de bout en bout par l’interface', async ({ browser }) => {
    const id = Date.now();
    const titre = `Console neuve sous blister ${id}`;
    const auteur = await (await browser.newContext()).newPage();
    const temoin = await (await browser.newContext()).newPage();
    const admin = await (await browser.newContext()).newPage();

    // 1. L'auteur publie une annonce
    await inscrire(auteur, `test-pw-auteur-${id}@exemple.ma`);
    await auteur.goto('/annonces/nouvelle');
    await auteur.getByLabel('Titre').fill(titre);
    await auteur.getByLabel('Catégorie').selectOption({ label: '— TV, audio & consoles' });
    await auteur.getByLabel('Prix (MAD)').fill('300');
    await auteur.getByLabel('Ville').fill('Casablanca');
    await auteur.getByLabel('Description').fill('Paiement uniquement par virement avant envoi.');
    await auteur.getByRole('button', { name: 'Publier' }).click();
    await expect(auteur.getByText('Annonce publiée.')).toBeVisible();
    const urlAnnonce = '/annonce/' + auteur.url().split('/').pop();

    // 2. Un autre membre la signale
    await inscrire(temoin, `test-pw-temoin-${id}@exemple.ma`);
    await temoin.goto(urlAnnonce);
    await temoin.getByText('Signaler cette annonce').click();
    await temoin.getByLabel('Motif').selectOption('ARNAQUE');
    await temoin.getByLabel(/Précisions/).fill('Demande de virement avant envoi.');
    await temoin.getByRole('button', { name: 'Envoyer le signalement' }).click();
    await expect(temoin.getByText('Merci : votre signalement sera examiné')).toBeVisible();

    // 3. L'administrateur le traite
    await admin.goto('/connexion');
    await admin.getByLabel('Email').fill('admin@exemple.ma');
    await admin.getByLabel('Mot de passe').fill('Demo1234!');
    await admin.getByRole('button', { name: 'Se connecter' }).click();
    await admin.getByRole('link', { name: /signalement\(s\) ouvert\(s\)/ }).click();
    await admin.getByRole('link', { name: titre }).click();
    await expect(admin.getByText('Demande de virement avant envoi.')).toBeVisible();
    await admin.setViewportSize({ width: 1280, height: 900 });
    await admin.screenshot({ path: `${CAPTURES}/etape7-signalement.png`, fullPage: true });
    admin.once('dialog', (dialogue) => dialogue.accept());   // « Approuver : l'annonce sera retirée… »
    await admin.getByRole('button', { name: 'Approuver : retirer le contenu' }).click();
    await expect(admin.getByText('Signalement approuvé : le contenu a été retiré.')).toBeVisible();

    // 4. Résultat : invisible du public, l'auteur voit pourquoi
    const reponse = await temoin.goto(urlAnnonce);
    expect(reponse.status()).toBe(404);
    await auteur.goto('/mes-annonces');
    await expect(auteur.locator('.ligne-annonce', { hasText: titre })).toContainText('Refusée');
    await auteur.goto(urlAnnonce);
    await expect(auteur.getByText('Retirée après signalement (ARNAQUE)')).toBeVisible();
});

test('tableau de bord administrateur : graphiques', async ({ page }) => {
    await page.goto('/connexion');
    await page.getByLabel('Email').fill('admin@exemple.ma');
    await page.getByLabel('Mot de passe').fill('Demo1234!');
    await page.getByRole('button', { name: 'Se connecter' }).click();
    await expect(page).toHaveURL(/\/admin$/);
    await expect(page.locator('#graphique-vendeurs rect.graphique__barre')).toHaveCount(8);   // 8 boutiques ont vendu
    await page.getByLabel('Période').selectOption('365');
    await expect(page.locator('#graphique-jours path.graphique__ligne')).toHaveCount(1);
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.screenshot({ path: `${CAPTURES}/etape7-admin.png`, fullPage: true });
});
