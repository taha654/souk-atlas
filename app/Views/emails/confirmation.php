<?php
/** Email texte (pas de HTML) : aucun échappement HTML ici, e() n'a pas de sens */
/** @var array<string, mixed> $achat */
/** @var string $nom */
/** @var string $url */
?>
Bonjour <?= $nom ?>,

Merci pour votre achat sur Souk Atlas. Il est bien enregistré sous la référence <?= $achat['reference'] ?>.

<?php foreach ($achat['commandes'] as $c): ?>
Commande <?= $c['numero'] ?> — expédiée par <?= $c['boutique'] ?>

<?php foreach ($c['lignes'] as $l): ?>
  - <?= $l['quantite'] ?> x <?= $l['nom'] ?>

<?php endforeach; ?>
  Total : <?= format_prix($c['total_ttc']) ?> TTC

<?php endforeach; ?>
Total de l'achat : <?= format_prix($achat['total_ttc']) ?> TTC
Paiement : <?= $achat['mode_paiement'] === 'CARTE' ? 'carte bancaire **** ' . $achat['carte_4_derniers'] : 'à la livraison' ?>

Livraison : <?= $achat['adresse'] ?>, <?= $achat['ville'] ?>


Suivre votre achat et télécharger la facture : <?= $url ?>


L'équipe Souk Atlas
(Email de démonstration : aucun paiement réel n'a eu lieu.)
