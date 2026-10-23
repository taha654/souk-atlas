<?php
/** @var list<array<string, mixed>> $jetons */
/** @var string|null $nouveau jeton en clair, affiché une seule fois juste après sa création */
/** @var array<string, string> $erreurs */

use App\Core\Csrf;
use App\Models\JetonApi;
?>
<p><a href="/compte">← Mon compte</a></p>

<section class="carte">
    <h1>Jetons d'accès à l'API</h1>
    <p>Un jeton permet à l'outil en ligne de commande <code>souk-console</code> d'agir en votre nom
        (import de produits, rapports de ventes, modération pour un administrateur).
        Traitez-le comme un mot de passe : ne le partagez pas, révoquez-le s'il a fuité.</p>

    <?php if ($nouveau !== null): ?>
        <div class="alerte alerte--succes" role="status">
            <p><strong>Jeton créé.</strong> Copiez-le maintenant : il ne sera plus jamais affiché
                (le site n'en garde qu'une empreinte).</p>
            <p><label for="jeton-cree">Votre jeton</label>
                <input id="jeton-cree" class="jeton" type="text" readonly value="<?= e($nouveau) ?>"></p>
            <p>Exemple : <code>export SOUK_JETON=<?= e($nouveau) ?></code></p>
        </div>
    <?php endif; ?>
    <?php if (isset($erreurs['general'])): ?>
        <p class="alerte alerte--erreur" role="alert"><?= e($erreurs['general']) ?></p>
    <?php endif; ?>

    <h2>Nouveau jeton</h2>
    <form method="post" action="/compte/jetons" class="form-en-ligne" novalidate data-valider>
        <?= Csrf::champ() ?>
        <div class="champ">
            <label for="libelle">Nom du jeton</label>
            <input id="libelle" name="libelle" type="text" required maxlength="100" placeholder="Ordinateur du bureau">
        </div>
        <div class="champ">
            <label for="jours">Valable</label>
            <select id="jours" name="jours">
                <?php foreach (JetonApi::DUREES as $j): ?>
                    <option value="<?= $j ?>" <?= $j === 30 ? 'selected' : '' ?>><?= $j ?> jours</option>
                <?php endforeach; ?>
            </select>
        </div>
        <button type="submit" class="bouton">Créer le jeton</button>
    </form>

    <h2>Mes jetons</h2>
    <?php if ($jetons === []): ?>
        <p>Aucun jeton pour l'instant.</p>
    <?php else: ?>
        <table class="tableau-donnees">
            <thead><tr><th scope="col">Nom</th><th scope="col">Créé le</th><th scope="col">Expire le</th>
                <th scope="col">Dernière utilisation</th><th scope="col">État</th><th scope="col"><span class="visuellement-cache">Action</span></th></tr></thead>
            <tbody>
            <?php foreach ($jetons as $j): ?>
                <tr>
                    <td><?= e($j['libelle']) ?></td>
                    <td><?= e(date_fr($j['creation'])) ?></td>
                    <td><?= e(date_fr($j['expiration'])) ?></td>
                    <td><?= $j['derniere_utilisation'] === null ? 'Jamais' : e(date_fr($j['derniere_utilisation'], true)) ?></td>
                    <td><?= e($j['etat']) ?></td>
                    <td><?php if ($j['etat'] === 'Valide'): ?>
                        <form method="post" action="/compte/jetons/<?= e($j['id']) ?>/revoquer"
                              data-confirmer="Révoquer ce jeton ? La console qui l'utilise ne pourra plus se connecter.">
                            <?= Csrf::champ() ?>
                            <button type="submit" class="bouton bouton--secondaire">Révoquer</button>
                        </form>
                    <?php endif; ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    <?php endif; ?>
</section>
