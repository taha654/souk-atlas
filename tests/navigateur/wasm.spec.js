// =============================================================================
// Tests navigateur de l'étape 10 : module WebAssembly et repli JavaScript.
// Critères : « smartphon samsng » trouve « Smartphone Samsung » ;
//            une photo de 5 Mo part allégée.
// =============================================================================
import { test, expect } from '@playwright/test';

const CAPTURES = '../../docs/captures';

/** Erreurs JavaScript : font échouer le test (sauf quand on provoque exprès une panne) */
test.beforeEach(async ({ page }) => {
    const erreurs = [];
    page.on('pageerror', (erreur) => erreurs.push(erreur.message));
    page.on('console', (message) => { if (message.type() === 'error') erreurs.push(message.text()); });
    test.info().erreursConsole = erreurs;
});
test.afterEach(async () => {
    if (!test.info().annotations.some((a) => a.type === 'panne-volontaire')) {
        expect(test.info().erreursConsole, 'erreurs dans la console du navigateur').toEqual([]);
    }
});

async function chercher(page, texte) {
    await page.getByRole('combobox', { name: /Rechercher/ }).fill(texte);
    return page.getByRole('listbox');
}

for (const [moteur, url] of [['WebAssembly', '/'], ['JavaScript', '/?moteur=js']]) {
    test(`recherche tolérante (${moteur}) : « smartphon samsng » trouve « Smartphone Samsung »`, async ({ page }) => {
        const wasm = [];
        page.on('request', (requete) => { if (requete.url().endsWith('.wasm')) wasm.push(requete.url()); });
        await page.goto(url);
        const liste = await chercher(page, 'smartphon samsng');
        const option = liste.getByRole('option', { name: /Smartphone Samsung Galaxy A55/ });
        await expect(option).toBeVisible();
        await expect(option).toContainText('orthographe approchée');
        await expect(liste).toHaveAttribute('data-moteur', moteur);
        await expect(liste.getByRole('option', { name: /Xiaomi/ })).toHaveCount(0);   // pas n'importe quoi
        expect(wasm.length > 0).toBe(moteur === 'WebAssembly');

        // Une autre faute, une transposition : « Samsugn »
        await chercher(page, 'tablete samsugn');
        await expect(page.getByRole('option', { name: /Tablette Samsung/ })).toBeVisible();
        if (moteur === 'WebAssembly') {
            await page.setViewportSize({ width: 1280, height: 600 });
            await chercher(page, 'smartphon samsng');
            await expect(option).toBeVisible();
            await page.screenshot({ path: `${CAPTURES}/etape10-recherche-tolerante.png` });
        }
    });
}

test('repli JavaScript si le fichier .wasm ne se charge pas', async ({ page }) => {
    // La panne provoquée écrit des erreurs dans la console : c'est attendu ici
    test.info().annotations.push({ type: 'panne-volontaire' });
    await page.route('**/*.wasm', (route) => route.abort());
    await page.goto('/');
    const liste = await chercher(page, 'smartphon samsng');
    await expect(liste.getByRole('option', { name: /Smartphone Samsung Galaxy A55/ })).toBeVisible();
    await expect(liste).toHaveAttribute('data-moteur', 'JavaScript');
});

test('suggestions exactes du serveur en premier, puis les approchées', async ({ page }) => {
    await page.goto('/');
    const liste = await chercher(page, 'samsung');
    await expect(liste.getByRole('option').first()).not.toContainText('orthographe approchée');
});

/** Photo JPEG de 4000 × 3000 px et d'un peu plus de 5 Mo, générée dans le navigateur */
async function photoDeCinqMo(page) {
    const base64 = await page.evaluate(async () => {
        const toile = new OffscreenCanvas(4000, 3000);
        const ctx = toile.getContext('2d');
        const image = ctx.createImageData(4000, 3000);
        let graine = 42;   // hasard reproductible
        const hasard = () => ((graine = (graine * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
        for (let y = 0; y < 3000; y++) {
            for (let x = 0; x < 4000; x++) {
                const i = (y * 4000 + x) * 4;
                image.data[i] = (x / 16) % 256 + hasard() * 80;
                image.data[i + 1] = (y / 12) % 256 + hasard() * 80;
                image.data[i + 2] = 128 + hasard() * 80;
                image.data[i + 3] = 255;
            }
        }
        ctx.putImageData(image, 0, 0);
        const blob = await toile.convertToBlob({ type: 'image/jpeg', quality: 0.9 });
        const octets = new Uint8Array(await blob.arrayBuffer());
        let binaire = '';
        for (let i = 0; i < octets.length; i += 0x8000) binaire += String.fromCharCode(...octets.subarray(i, i + 0x8000));
        return btoa(binaire);
    });
    return Buffer.from(base64, 'base64');
}

for (const [moteur, suffixe] of [['WebAssembly', ''], ['JavaScript', '?moteur=js']]) {
    test(`une photo de 5 Mo part allégée (${moteur})`, async ({ page }) => {
        test.setTimeout(90_000);
        const email = `test-wasm-${moteur.toLowerCase()}@exemple.ma`;
        await page.goto('/inscription');
        await page.getByLabel('Nom complet').fill('Compte Test Photo');
        await page.getByLabel('Email').fill(email);
        await page.getByLabel('Mot de passe', { exact: true }).fill('motdepasse1');
        await page.getByLabel('Confirmer le mot de passe').fill('motdepasse1');
        await page.getByRole('button', { name: /Créer mon compte/ }).click();

        await page.goto('/annonces/nouvelle');
        await page.getByLabel('Titre').fill('Lampe en laiton test photo');
        await page.getByLabel('Description').fill('Lampe ciselée, très bon état.');
        await page.getByLabel(/Prix/).fill('350');
        await page.getByLabel('Ville').fill('Fès');
        await page.getByLabel('Catégorie').selectOption('14');   // Tapis & artisanat
        await page.getByRole('button', { name: /Publier/ }).click();
        await expect(page).toHaveURL(/\/mes-annonces\/\d+$/);
        if (suffixe) await page.goto(page.url() + suffixe);

        const photo = await photoDeCinqMo(page);
        expect(photo.length).toBeGreaterThan(5 * 1024 * 1024);   // au-delà de la limite du serveur

        await page.getByLabel(/Ajouter une photo/).setInputFiles({ name: 'photo-5mo.jpg', mimeType: 'image/jpeg', buffer: photo });
        const message = page.locator('.photo-allegee');
        await expect(message).toContainText('Photo allégée : 5,', { timeout: 30_000 });
        await expect(message).toHaveAttribute('data-moteur', moteur);
        const taille = await page.getByLabel(/Ajouter une photo/).evaluate((champ) => champ.files[0].size);
        expect(taille).toBeLessThan(1024 * 1024);   // moins d'1 Mo au lieu de plus de 5
        if (moteur === 'WebAssembly') await page.screenshot({ path: `${CAPTURES}/etape10-photo-allegee.png` });

        // Ce qui part réellement sur le réseau
        const [envoi] = await Promise.all([
            page.waitForRequest((r) => r.method() === 'POST' && /\/photos$/.test(r.url())),
            page.getByRole('button', { name: 'Envoyer' }).click(),
        ]);
        // (Playwright ne donne pas le corps d'un envoi de fichier : on lit sa longueur annoncée)
        expect(Number((await envoi.allHeaders())['content-length'])).toBeLessThan(1024 * 1024);
        await expect(page.getByText('Photo ajoutée.')).toBeVisible();

        // La photo enregistrée par le serveur fait 1600 × 1200 px
        const dimensions = await page.locator('.photos-vendeur img').first().evaluate(async (img) => {
            await img.decode();
            return [img.naturalWidth, img.naturalHeight];
        });
        expect(dimensions).toEqual([1600, 1200]);
    });
}
