// =============================================================================
// Tests navigateur de l'étape 3 : catalogue, recherche, fiche produit.
// Critère de l'étape : « Recherche et filtres fonctionnent sans rechargement ».
// =============================================================================
import { test, expect } from '@playwright/test';
import { capturer } from './captures.js';


/**
 * Un rechargement de page efface tout ce qui est stocké dans `window`.
 * On pose donc un marqueur avant l'action, et on vérifie qu'il existe toujours après.
 */
async function poserMarqueur(page) {
    await page.evaluate(() => { window.__marqueurSansRechargement = true; });
}
async function pageNonRechargee(page) {
    return page.evaluate(() => window.__marqueurSansRechargement === true);
}

/** Échoue le test à la moindre erreur JavaScript ou violation de CSP dans la console */
test.beforeEach(async ({ page }) => {
    const erreurs = [];
    page.on('pageerror', (erreur) => erreurs.push(erreur.message));
    page.on('console', (message) => { if (message.type() === 'error') erreurs.push(message.text()); });
    test.info().erreursConsole = erreurs;
});
test.afterEach(async () => {
    expect(test.info().erreursConsole, 'erreurs dans la console du navigateur').toEqual([]);
});

test.describe('Catalogue sans rechargement', () => {
    test('choisir une catégorie filtre la liste et met à jour l’URL', async ({ page }) => {
        await page.goto('/catalogue');
        await poserMarqueur(page);
        // Tri alphabétique français : « Électronique » vient avant « Maison & cuisine »
        const racines = await page.locator('.arbre-categories .niveau-1').allTextContents();
        expect(racines.map((t) => t.trim().replace(/\s*\(\d+\)$/, ''))).toEqual(
            ['Beauté & santé', 'Bébé & jouets', 'Électronique', 'Maison & cuisine', 'Mode', 'Sport & loisirs']);

        await page.getByRole('radio', { name: /^Smartphones/ }).check();

        await expect(page.locator('#nb-resultats')).toHaveText('4 produits trouvés');
        await expect(page.locator('#liste-produits .carte-produit')).toHaveCount(4);
        await expect(page).toHaveURL(/\/catalogue\?categorie=3$/);
        expect(await pageNonRechargee(page)).toBe(true);
    });

    test('le tri par prix croissant ordonne les cartes', async ({ page }) => {
        await page.goto('/catalogue?categorie=3');
        await poserMarqueur(page);

        await page.getByLabel('Trier par').selectOption('prix_asc');
        await expect(page).toHaveURL(/tri=prix_asc/);

        const prix = await page.locator('#liste-produits .carte-produit__prix strong').allTextContents();
        // "2 365,20 MAD" → 2365.2
        const nombres = prix.map((t) => Number(t.replace(/[^\d,]/g, '').replace(',', '.')));
        expect(nombres).toEqual([...nombres].sort((a, b) => a - b));
        expect(await pageNonRechargee(page)).toBe(true);
    });

    test('la saisie des mots-clés n’envoie qu’une requête (debounce)', async ({ page }) => {
        await page.goto('/catalogue');
        await poserMarqueur(page);
        const requetes = [];
        page.on('request', (r) => { if (r.url().includes('/api/produits')) requetes.push(r.url()); });

        // 5 frappes rapides (50 ms entre chaque) : moins que le délai de 400 ms
        await page.getByLabel('Mots-clés').pressSequentially('ecran', { delay: 50 });
        await expect(page.locator('#nb-resultats')).toHaveText(/8 produits trouvés/);

        expect(requetes).toHaveLength(1);
        expect(requetes[0]).toContain('q=ecran');
        // Recherche insensible aux accents : "ecran" trouve "Écran"
        await expect(page.locator('#liste-produits')).toContainText('Écran 24 pouces Full HD');
        await expect(page.locator('#titre-catalogue')).toHaveText('Résultats pour « ecran »');
        expect(await pageNonRechargee(page)).toBe(true);
    });

    test('« Précédent » restaure les filtres et les résultats sans recharger', async ({ page }) => {
        await page.goto('/catalogue');
        await poserMarqueur(page);

        await page.getByRole('radio', { name: /^Smartphones/ }).check();
        await expect(page.locator('#nb-resultats')).toHaveText('4 produits trouvés');
        await page.getByLabel('En stock uniquement').check();
        await expect(page).toHaveURL(/categorie=3&en_stock=1/);

        await page.goBack();
        await expect(page).toHaveURL(/\/catalogue\?categorie=3$/);
        await expect(page.getByLabel('En stock uniquement')).not.toBeChecked();
        await expect(page.getByRole('radio', { name: /^Smartphones/ })).toBeChecked();

        await page.goBack();
        await expect(page).toHaveURL(/\/catalogue$/);
        await expect(page.getByLabel('Toutes les catégories')).toBeChecked();
        await expect(page.locator('#liste-produits .carte-produit')).toHaveCount(12);
        expect(await pageNonRechargee(page)).toBe(true);
    });

    test('la pagination change de page sans recharger', async ({ page }) => {
        await page.goto('/catalogue');
        await poserMarqueur(page);
        const premierePage = await page.locator('.carte-produit__nom').first().textContent();

        await page.locator('#pagination').getByRole('link', { name: '2', exact: true }).click();

        await expect(page).toHaveURL(/page=2/);
        await expect(page.locator('#pagination [aria-current="page"]')).toHaveText('2');
        await expect(page.locator('.carte-produit__nom').first()).not.toHaveText(premierePage);
        expect(await pageNonRechargee(page)).toBe(true);
    });

    test('un filtre sans résultat affiche le message prévu', async ({ page }) => {
        await page.goto('/catalogue');
        await page.getByLabel('Mots-clés').fill('introuvablexyz');
        await expect(page.locator('#nb-resultats')).toHaveText('Aucun produit trouvé');
        await expect(page.locator('#aucun-resultat')).toBeVisible();
        await expect(page.locator('#pagination li')).toHaveCount(0);
    });

    test('du HTML tapé dans la recherche reste du texte (XSS)', async ({ page }) => {
        await page.goto('/catalogue');
        page.on('dialog', () => { throw new Error('une alerte JavaScript a été exécutée'); });
        await page.getByLabel('Mots-clés').fill('<img src=x onerror=alert(1)>');
        await expect(page.locator('#titre-catalogue')).toHaveText('Résultats pour « <img src=x onerror=alert(1)> »');
        await expect(page.locator('#titre-catalogue img')).toHaveCount(0);
    });
});

test.describe('Autocomplétion', () => {
    test('suggestions au clavier : ↓ puis Entrée ouvre le produit', async ({ page }) => {
        await page.goto('/');
        const champ = page.getByRole('combobox', { name: 'Rechercher un produit' });
        await champ.pressSequentially('smart', { delay: 30 });

        const liste = page.getByRole('listbox', { name: 'Suggestions' });
        await expect(liste).toBeVisible();
        await expect(liste.getByRole('option')).toHaveCount(4);
        await expect(champ).toHaveAttribute('aria-expanded', 'true');

        await champ.press('ArrowDown');
        await expect(champ).toHaveAttribute('aria-activedescendant', 'suggestion-0');
        await expect(liste.getByRole('option').first()).toHaveAttribute('aria-selected', 'true');
        const nom = await liste.getByRole('option').first().textContent();

        await champ.press('Enter');
        await expect(page).toHaveURL(/\/produit\/\d+$/);
        await expect(page.getByRole('heading', { level: 1 })).toHaveText(nom);
    });

    test('Échap ferme la liste ; 1 seul caractère ne déclenche rien', async ({ page }) => {
        await page.goto('/');
        const champ = page.getByRole('combobox', { name: 'Rechercher un produit' });
        await champ.pressSequentially('gal', { delay: 30 });
        await expect(page.getByRole('listbox')).toBeVisible();
        await champ.press('Escape');
        await expect(page.getByRole('listbox')).toBeHidden();
        await expect(champ).toHaveAttribute('aria-expanded', 'false');

        await champ.fill('');
        await champ.pressSequentially('g');
        await page.waitForTimeout(400);
        await expect(page.getByRole('listbox')).toBeHidden();
    });

    test('Entrée sans suggestion choisie lance la recherche complète', async ({ page }) => {
        await page.goto('/');
        const champ = page.getByRole('combobox', { name: 'Rechercher un produit' });
        await champ.pressSequentially('samsung', { delay: 30 });
        await expect(page.getByRole('listbox')).toBeVisible();
        await champ.press('Enter');
        await expect(page).toHaveURL(/\/catalogue\?q=samsung$/);
        await expect(page.locator('#nb-resultats')).toHaveText('3 produits trouvés');
    });
});

test.describe('Fiche produit', () => {
    test('la galerie change de photo au clic et aux flèches', async ({ page }) => {
        await page.goto('/produit/2');   // produit 2 : 3 illustrations
        const image = page.locator('[data-galerie-image]');
        const vignettes = page.locator('.galerie__vignette');
        await expect(vignettes).toHaveCount(3);

        await vignettes.nth(1).click();
        await expect(image).toHaveAttribute('src', /produit-2-2\.svg$/);
        await expect(vignettes.nth(1)).toHaveAttribute('aria-pressed', 'true');

        await vignettes.nth(1).press('ArrowRight');
        await expect(image).toHaveAttribute('src', /produit-2-3\.svg$/);
        await expect(vignettes.nth(2)).toBeFocused();
        await vignettes.nth(2).press('ArrowRight');   // dernière → première
        await expect(image).toHaveAttribute('src', /produit-2-1\.svg$/);
    });

    test('prix TTC, prix barré et promotion affichés', async ({ page }) => {
        await page.goto('/produit/1');
        await expect(page.locator('.prix-ttc')).toContainText('MAD');
        await expect(page.locator('.prix-ht')).toContainText('HT');
        await expect(page.getByRole('navigation', { name: 'Fil d’Ariane' }).or(
            page.getByRole('navigation', { name: "Fil d'Ariane" }))).toContainText('Smartphones');
    });
});

test('sans JavaScript, les filtres fonctionnent quand même (rechargement classique)', async ({ browser }) => {
    const contexte = await browser.newContext({ javaScriptEnabled: false });
    const page = await contexte.newPage();
    await page.goto('/catalogue');
    await page.getByRole('radio', { name: /^Smartphones/ }).check();
    await page.getByRole('button', { name: 'Appliquer' }).click();
    await expect(page).toHaveURL(/categorie=3/);
    await expect(page.locator('#nb-resultats')).toHaveText('4 produits trouvés');
    await contexte.close();
});

test('captures d’écran pour le portfolio', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto('/catalogue?categorie=1');
    await capturer(page, 'etape3-catalogue.png', { fullPage: true });
    await page.goto('/produit/1');
    await capturer(page, 'etape3-fiche-produit.png', { fullPage: true });
    await page.setViewportSize({ width: 390, height: 844 });   // téléphone
    await page.goto('/catalogue?q=samsung');
    // Sur petit écran, les filtres sont repliés : les produits apparaissent tout de suite
    await expect(page.locator('.filtres__bascule')).not.toHaveAttribute('open', '');
    await expect(page.locator('#liste-produits .carte-produit').first()).toBeInViewport();
    await capturer(page, 'etape3-catalogue-mobile.png', { fullPage: true });
});
