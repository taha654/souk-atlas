<?php
// Page de vérification : la chaîne complète navigateur → PHP → Oracle fonctionne.
// Ce fichier deviendra le contrôleur frontal à l'étape 2.

declare(strict_types=1);

function e(string $texte): string
{
    // Échappement HTML : aucune donnée n'est affichée sans passer par ici
    return htmlspecialchars($texte, ENT_QUOTES, 'UTF-8');
}

$message = null;
$version = null;
$erreur  = null;

// AL32UTF8 : l'encodage UTF-8 d'Oracle, pour que les accents arrivent intacts
$connexion = @oci_connect(getenv('DB_USER'), getenv('DB_PASSWORD'), getenv('DB_DSN'), 'AL32UTF8');

if ($connexion === false) {
    $erreur = oci_error()['message'] ?? 'Connexion impossible';
} else {
    // Étape 1 : le vrai schéma remplace la table HELLO de l'étape 0
    $requete = oci_parse($connexion,
        "SELECT (SELECT COUNT(*) FROM produit WHERE statut = 'ACTIF') AS produits,
                (SELECT COUNT(*) FROM annonce WHERE statut = 'EN_LIGNE') AS annonces,
                pkg_catalogue.chemin_categorie(:id_categorie) AS chemin
           FROM dual");
    $idCategorie = 3;
    oci_bind_by_name($requete, ':id_categorie', $idCategorie); // variable liée, jamais de concaténation
    oci_execute($requete);
    $ligne = oci_fetch_assoc($requete);
    $message = sprintf('%d produits en vente, %d annonces en ligne. Catégorie n°3 : %s',
        $ligne['PRODUITS'], $ligne['ANNONCES'], $ligne['CHEMIN']);

    $requete = oci_parse($connexion, 'SELECT banner_full FROM v$version');
    oci_execute($requete);
    $version = oci_fetch_assoc($requete)['BANNER_FULL'] ?? '';

    oci_close($connexion);
}
?>
<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Souk Atlas — Hello</title>
</head>
<body>
    <h1>Souk Atlas</h1>
    <?php if ($erreur !== null): ?>
        <p><strong>Erreur Oracle :</strong> <?= e($erreur) ?></p>
    <?php else: ?>
        <p><strong>Message lu dans Oracle :</strong> <?= e($message) ?></p>
        <p><small><?= e($version) ?> — PHP <?= e(PHP_VERSION) ?></small></p>
    <?php endif; ?>
</body>
</html>
