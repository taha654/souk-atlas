<?php
/** Layout minimal des documents à imprimer (facture) : ni menu ni pied de page */
/** @var string $contenu */
/** @var string $titre */
?>
<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($titre) ?> · Souk Atlas</title>
    <link rel="stylesheet" href="/assets/css/facture.css">
</head>
<body>
<?= $contenu ?>
</body>
</html>
