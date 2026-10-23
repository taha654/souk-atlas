<?php
/** @var array<string, mixed> $annonce */
/** @var list<array{id: int, nom: string}> $chemin */

use App\Core\Auth;
use App\Core\Csrf;
use App\Models\Annonce;

$photos = array_column($annonce['photos'], 'chemin') ?: ['/assets/img/aucune-photo.svg'];
$moi = Auth::utilisateur();
$peutInteragir = $moi !== null && !$annonce['est_auteur'] && in_array($moi['role'], ['CLIENT', 'VENDEUR'], true);
$motifs = ['ARNAQUE' => 'Arnaque ou fraude', 'CONTREFACON' => 'Contrefaçon', 'INAPPROPRIE' => 'Contenu inapproprié',
           'DOUBLON' => 'Annonce en double', 'AUTRE' => 'Autre raison'];
?>
<nav class="fil-ariane" aria-label="Fil d'Ariane">
    <ol>
        <li><a href="/annonces">Annonces</a></li>
        <?php foreach ($chemin as $etape): ?>
            <li><a href="/annonces?categorie=<?= e($etape['id']) ?>"><?= e($etape['nom']) ?></a></li>
        <?php endforeach; ?>
        <li><span aria-current="page"><?= e($annonce['titre']) ?></span></li>
    </ol>
</nav>

<?php if ($annonce['statut'] !== 'EN_LIGNE'): ?>
    <p class="alerte alerte--info">Statut de votre annonce : <strong><?= e(Annonce::STATUTS[$annonce['statut']]) ?></strong>.
        <?= $annonce['motif_refus'] !== null ? 'Motif : ' . e($annonce['motif_refus']) . '.' : '' ?>
        Elle n'est visible que par vous.</p>
<?php endif; ?>

<article class="fiche-produit">
    <section class="galerie" aria-label="Photos de l'annonce" data-galerie>
        <figure class="galerie__principale">
            <img src="<?= e($photos[0]) ?>" alt="<?= e($annonce['titre']) ?>, photo 1 sur <?= count($photos) ?>" width="600" height="450" data-galerie-image>
        </figure>
        <?php if (count($photos) > 1): ?>
            <ul class="galerie__vignettes">
                <?php foreach ($photos as $i => $photo): ?>
                    <li><button type="button" class="galerie__vignette" data-src="<?= e($photo) ?>"
                                data-alt="<?= e($annonce['titre']) ?>, photo <?= $i + 1 ?> sur <?= count($photos) ?>"
                                aria-label="Afficher la photo <?= $i + 1 ?>" aria-pressed="<?= $i === 0 ? 'true' : 'false' ?>">
                        <img src="<?= e($photo) ?>" alt="" width="120" height="90"></button></li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </section>

    <section class="fiche-produit__infos">
        <h1><?= e($annonce['titre']) ?></h1>
        <p class="prix-ttc"><?= $annonce['prix'] > 0 ? e(format_prix($annonce['prix'])) : 'Don (gratuit)' ?></p>
        <p><?= e($annonce['ville']) ?> · publiée le <?= e(date_fr($annonce['date_publication'])) ?>
            <small class="facultatif">(jusqu'au <?= e(date_fr($annonce['date_expiration'])) ?>)</small></p>
        <p>Vendeur : <strong><?= e($annonce['auteur']) ?></strong>, membre depuis <?= e(date_fr($annonce['membre_depuis'])) ?></p>

        <h2>Description</h2>
        <p><?= nl2br(e($annonce['description'])) ?></p>

        <?php if ($annonce['est_auteur']): ?>
            <p><a class="bouton" href="/mes-annonces/<?= e($annonce['id']) ?>">Gérer mon annonce</a></p>
        <?php elseif ($peutInteragir): ?>
            <section class="carte" aria-labelledby="titre-contact">
                <h2 id="titre-contact">Contacter <?= e($annonce['auteur']) ?></h2>
                <form method="post" action="/annonce/<?= e($annonce['id']) ?>/contacter">
                    <?= Csrf::champ() ?>
                    <label for="message" class="visuellement-cache">Votre message</label>
                    <textarea id="message" name="message" rows="3" maxlength="2000" required>Bonjour, votre annonce « <?= e($annonce['titre']) ?> » est-elle toujours disponible ?</textarea>
                    <button type="submit" class="bouton">Envoyer le message</button>
                </form>
            </section>
            <form method="post" action="/annonce/<?= e($annonce['id']) ?>/favori">
                <?= Csrf::champ() ?>
                <input type="hidden" name="favori" value="<?= $annonce['en_favori'] ? '0' : '1' ?>">
                <button type="submit" class="bouton-lien" aria-pressed="<?= $annonce['en_favori'] ? 'true' : 'false' ?>">
                    <?= $annonce['en_favori'] ? '★ Retirer de mes favoris' : '☆ Ajouter à mes favoris' ?></button>
            </form>
            <details class="signalement">
                <summary>Signaler cette annonce</summary>
                <form method="post" action="/annonce/<?= e($annonce['id']) ?>/signaler">
                    <?= Csrf::champ() ?>
                    <div class="champ"><label for="motif">Motif</label>
                        <select id="motif" name="motif" required>
                            <?php foreach ($motifs as $code => $libelle): ?><option value="<?= e($code) ?>"><?= e($libelle) ?></option><?php endforeach; ?>
                        </select></div>
                    <div class="champ"><label for="commentaire">Précisions <span class="facultatif">(facultatif)</span></label>
                        <textarea id="commentaire" name="commentaire" rows="2" maxlength="1000"></textarea></div>
                    <button type="submit" class="bouton bouton--secondaire">Envoyer le signalement</button>
                </form>
            </details>
        <?php elseif ($moi === null): ?>
            <p><a class="bouton" href="/connexion?retour=<?= e(rawurlencode('/annonce/' . $annonce['id'])) ?>">Se connecter pour contacter le vendeur</a></p>
        <?php endif; ?>
    </section>
</article>

<script type="module" src="/assets/js/galerie.js"></script>
