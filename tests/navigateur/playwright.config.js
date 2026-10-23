// Configuration Playwright. Les tests tournent dans le conteneur officiel
// Playwright, branché sur le réseau Docker du projet : le site s'appelle "php".
import { defineConfig } from '@playwright/test';

export default defineConfig({
    testDir: '.',
    timeout: 30_000,
    fullyParallel: false,       // une seule base partagée : pas de tests simultanés
    reporter: [['list']],
    use: {
        baseURL: process.env.BASE ?? 'http://php',
        locale: 'fr-FR',
        trace: 'retain-on-failure',
    },
    outputDir: './resultats',
});
