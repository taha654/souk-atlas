<?php
/** @var array<string, mixed> $conversation */
/** @var list<array<string, mixed>> $messages */

use App\Core\Csrf;
?>
<p><a href="/messages">← Mes messages</a></p>
<h1><?= e($conversation['titre']) ?></h1>
<p>Avec <?= e($conversation['interlocuteur']) ?> (<?= $conversation['je_vends'] ? 'acheteur' : 'vendeur' ?>) ·
    <a href="/annonce/<?= e($conversation['id_annonce']) ?>">voir l'annonce</a></p>

<?php /* role="log" + aria-live : les nouveaux messages sont annoncés aux lecteurs d'écran */ ?>
<ol class="fil-messages" id="fil-messages" role="log" aria-live="polite" aria-label="Messages"
    data-conversation="<?= e($conversation['id']) ?>">
    <?php foreach ($messages as $m): ?>
        <li class="message <?= $m['moi'] ? 'message--moi' : '' ?>" data-id="<?= e($m['id']) ?>">
            <p class="message__entete"><?= $m['moi'] ? 'Moi' : e($m['expediteur']) ?> · <?= e(date_fr($m['date'], true)) ?></p>
            <p class="message__contenu"><?= nl2br(e($m['contenu'])) ?></p>
        </li>
    <?php endforeach; ?>
</ol>

<form method="post" action="/messages/<?= e($conversation['id']) ?>" class="carte formulaire-message" id="formulaire-message">
    <?= Csrf::champ() ?>
    <label for="message">Votre message</label>
    <textarea id="message" name="message" rows="3" maxlength="2000" required></textarea>
    <button type="submit" class="bouton">Envoyer</button>
    <p id="etat-message" class="facultatif" aria-live="polite"></p>
</form>

<script type="module" src="/assets/js/messagerie.js"></script>
