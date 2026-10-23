<?php
/** @var array<string, mixed> $aTraiter */
?>
<section class="carte">
    <h1>Administration</h1>
    <div class="grille-chiffres">
        <div class="chiffre"><strong><?= e($aTraiter['BOUTIQUES']) ?></strong> boutique(s) à valider</div>
        <div class="chiffre"><strong><?= e($aTraiter['ANNONCES']) ?></strong> annonce(s) à modérer</div>
        <div class="chiffre"><strong><?= e($aTraiter['SIGNALEMENTS']) ?></strong> signalement(s) ouvert(s)</div>
        <div class="chiffre"><strong><?= e($aTraiter['UTILISATEURS']) ?></strong> utilisateurs</div>
    </div>
    <p class="sous-texte">Les outils de modération arrivent à l'étape 7.</p>
</section>
