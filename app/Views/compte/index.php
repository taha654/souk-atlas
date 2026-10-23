<?php
/** @var array<string, mixed> $compte */

$roles = ['CLIENT' => 'Particulier', 'VENDEUR' => 'Vendeur professionnel', 'ADMIN' => 'Administrateur'];
?>
<section class="carte">
    <h1>Mon compte</h1>
    <dl class="fiche">
        <dt>Nom</dt>        <dd><?= e($compte['NOM']) ?></dd>
        <dt>Email</dt>      <dd><?= e($compte['EMAIL']) ?></dd>
        <dt>Téléphone</dt>  <dd><?= e($compte['TELEPHONE'] ?? '—') ?></dd>
        <dt>Ville</dt>      <dd><?= e($compte['VILLE'] ?? '—') ?></dd>
        <dt>Type</dt>       <dd><?= e($roles[$compte['ROLE']] ?? $compte['ROLE']) ?></dd>
        <dt>Membre depuis</dt> <dd><?= e(date_fr($compte['DATE_CREATION'])) ?></dd>
        <dt>Dernière connexion</dt> <dd><?= e(date_fr($compte['DATE_DERNIERE_CONNEXION'], true)) ?></dd>
    </dl>
</section>
