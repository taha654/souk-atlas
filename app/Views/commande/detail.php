<?php
/** @var array<string, mixed> $commande */

use App\Core\Csrf;
use App\Models\Commande;

$retour = '/commande/' . rawurlencode($commande['numero']);
$annulee = $commande['statut'] === 'ANNULEE';
$rang = array_search($commande['statut'], array_keys(Commande::ETAPES), true);
?>
<p><a href="/mes-commandes">← Mes commandes</a></p>

<section class="carte">
    <h1>Commande <?= e($commande['numero']) ?></h1>
    <p>Achat <a href="/achat/<?= e(rawurlencode($commande['reference'])) ?>"><?= e($commande['reference']) ?></a>
        · vendue par <?= e($commande['boutique']) ?> · <?= e(format_prix($commande['total_ttc'])) ?> TTC</p>

    <?php if ($annulee): ?>
        <p class="alerte alerte--erreur">Commande annulée le <?= e(date_fr($commande['dates']['ANNULEE'], true)) ?>.
            <?= $commande['statut_paiement'] === 'REMBOURSE' ? 'Votre paiement a été remboursé.' : '' ?></p>
    <?php else: ?>
        <?php /* Frise de suivi : une liste ordonnée, l'étape en cours marquée aria-current */ ?>
        <ol class="suivi" aria-label="Suivi de la commande">
            <?php foreach (Commande::ETAPES as $statut => $libelle): ?>
                <?php
                $index = array_search($statut, array_keys(Commande::ETAPES), true);
                // Paiement à la livraison : pas d'étape "Payée" avant l'expédition
                if ($statut === 'PAYEE' && $commande['mode_paiement'] === 'LIVRAISON') {
                    continue;
                }
                $faite = $index <= $rang;
                ?>
                <li class="suivi__etape <?= $faite ? 'suivi__etape--faite' : '' ?>"
                    <?= $statut === $commande['statut'] ? 'aria-current="step"' : '' ?>>
                    <span class="suivi__libelle"><?= e($libelle) ?></span>
                    <span class="suivi__date"><?= $faite ? e(date_fr($commande['dates'][$statut] ?? null, true)) : '—' ?></span>
                </li>
            <?php endforeach; ?>
        </ol>
    <?php endif; ?>

    <?php if ($commande['annulable']): ?>
        <form method="post" action="<?= e($retour) ?>/annuler" data-confirmer="Annuler cette commande ?">
            <?= Csrf::champ() ?>
            <button type="submit" class="bouton bouton--secondaire">Annuler la commande</button>
        </form>
    <?php endif; ?>
</section>

<section class="carte">
    <h2>Articles</h2>
    <ul class="liste-avis">
        <?php foreach ($commande['lignes'] as $l): ?>
            <li>
                <p><?= e($l['quantite']) ?> × <a href="/produit/<?= e($l['id_produit']) ?>"><?= e($l['nom']) ?></a>
                    — <?= e(format_prix($l['total_ligne_ht'])) ?> HT</p>
                <?php if ($l['peut_noter']): ?>
                    <details class="formulaire-avis">
                        <summary>Donner mon avis</summary>
                        <form method="post" action="/produit/<?= e($l['id_produit']) ?>/avis">
                            <?= Csrf::champ() ?>
                            <input type="hidden" name="retour" value="<?= e($retour) ?>">
                            <fieldset class="champ">
                                <legend>Note</legend>
                                <?php for ($n = 5; $n >= 1; $n--): ?>
                                    <label class="choix"><input type="radio" name="note" value="<?= $n ?>" required>
                                        <?= str_repeat('★', $n) ?> <span class="visuellement-cache"><?= $n ?> sur 5</span></label>
                                <?php endfor; ?>
                            </fieldset>
                            <div class="champ">
                                <label for="commentaire-<?= e($l['id_produit']) ?>">Commentaire <span class="facultatif">(facultatif)</span></label>
                                <textarea id="commentaire-<?= e($l['id_produit']) ?>" name="commentaire" maxlength="2000" rows="3"></textarea>
                            </div>
                            <button type="submit" class="bouton">Publier mon avis</button>
                        </form>
                    </details>
                <?php endif; ?>
            </li>
        <?php endforeach; ?>
    </ul>
</section>
