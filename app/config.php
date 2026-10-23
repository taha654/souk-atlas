<?php
declare(strict_types=1);

// Configuration lue dans les variables d'environnement (fournies par
// docker-compose.yml à partir du fichier .env) : aucun secret dans le code.

return [
    'env' => getenv('APP_ENV') ?: 'prod',
    // Adresse publique du site, pour les liens dans les emails
    'url' => rtrim(getenv('APP_URL') ?: 'http://localhost:8000', '/'),
    // Emails simulés : écrits dans des fichiers .eml (voir app/Services/Mailer.php)
    'dossier_mails' => dirname(__DIR__) . '/var/mails',

    'db' => [
        'utilisateur' => getenv('DB_USER') ?: '',
        'mot_de_passe' => getenv('DB_PASSWORD') ?: '',
        'dsn' => getenv('DB_DSN') ?: '',
    ],

    'session' => [
        'nom' => 'SOUKSESSID',
        'inactivite_secondes' => (int) (getenv('SESSION_INACTIVITE_SECONDES') ?: 1800),
        'cookie_secure_force' => getenv('SESSION_COOKIE_SECURE') === '1',
    ],

    // Limitation des tentatives de connexion (fenêtre glissante)
    'connexion' => [
        'fenetre_minutes' => 15,
        'max_echecs_email' => 5,
        // Plus haut que par email : une même IP publique peut être partagée
        // par toute une école, un cybercafé ou une famille
        'max_echecs_ip' => 20,
    ],
];
