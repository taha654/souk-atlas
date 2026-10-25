# Mettre Souk Atlas en ligne (Oracle Cloud Always Free, ARM64)

Ce guide met le site en ligne sur une VM **Oracle Cloud Always Free** : processeur
**Ampere A1 (ARM64)**, 2 cœurs, 12 Go de RAM, Ubuntu. Toutes les commandes sont à
taper **sur le serveur**, sauf mention contraire. Rien ici ne modifie votre
installation locale : `docker compose up` sous WSL fonctionne comme avant.

## Ce qui tourne sur le serveur

```
Internet ──► 80 / 443 ──► Caddy ──(réseau "web")──► Apache + PHP ──(réseau "base", interne)──► Oracle
                          HTTPS automatique         aucun port publié                        aucun port publié
```

| Fichier | Rôle |
|---|---|
| `docker-compose.prod.yml` | Les trois services de production (Oracle, PHP, Caddy) |
| `docker/php/Dockerfile` | Même recette qu'en local ; la cible `production` copie le code dans l'image |
| `docker/php/souk-prod.ini` | PHP de production : erreurs masquées, OPcache, cookie `Secure` |
| `docker/php/apache-prod.conf` | Vraie IP des visiteurs derrière Caddy (`mod_remoteip`) |
| `deploy/Caddyfile` | HTTPS, HSTS, compression, taille maximale des requêtes |
| `deploy.sh` | Premier déploiement et mises à jour |
| `deploy/reinitialiser_demo.sh` | Remise à zéro nocturne de la démonstration |
| `deploy/sauvegarder.sh`, `deploy/restaurer.sh` | Sauvegarde et restauration |
| `deploy/verifier_arm64.sh` | (sur votre PC) vérifie que l'image se construit en ARM64 |

---

## 1. Créer la VM (console Oracle Cloud, dans le navigateur)

1. **Compute → Instances → Create instance**.
2. **Image** : *Canonical Ubuntu 24.04*. **Shape** : *Ampere → VM.Standard.A1.Flex*,
   **2 OCPU** et **12 Go** de mémoire (dans la limite gratuite : 4 OCPU / 24 Go au total).
3. **Networking** : laissez créer un VCN et un sous-réseau **public**, avec
   « Assign a public IPv4 address ».
4. **SSH keys** : collez votre clé publique (sous WSL : `cat ~/.ssh/id_ed25519.pub` ;
   si elle n'existe pas : `ssh-keygen -t ed25519`).
5. **Boot volume** : 50 Go suffisent (jusqu'à 200 Go gratuits au total).

> « Out of capacity » à la création ? Les VM Ampere gratuites sont très demandées.
> Réessayez plus tard ou dans un autre *availability domain*.

Notez l'**adresse IP publique** de l'instance. Conseil : la transformer en IP
**réservée** (Networking → IP Management → Reserved public IPs) pour qu'elle ne
change jamais.

## 2. Ouvrir les ports 80 et 443 côté Oracle Cloud

Oracle Cloud filtre le trafic **avant** qu'il n'atteigne la VM (*Security List*).
Seul le port 22 y est ouvert par défaut.

**Networking → Virtual Cloud Networks → (votre VCN) → Security Lists → Default
Security List → Add Ingress Rules**, trois règles :

| Source CIDR | Protocole | Port de destination | Pour |
|---|---|---|---|
| `0.0.0.0/0` | TCP | 80 | HTTP (redirigé vers HTTPS, et validation Let's Encrypt) |
| `0.0.0.0/0` | TCP | 443 | HTTPS |
| `0.0.0.0/0` | UDP | 443 | HTTP/3 (facultatif) |

N'ouvrez **pas** 1521 ni 8000 : Oracle et PHP ne doivent jamais être joignables.

## 3. Un nom de domaine qui pointe vers la VM

Let's Encrypt ne délivre un certificat qu'à un **nom de domaine**, pas à une IP.

- **Vous avez un domaine** : chez votre registraire, créez un enregistrement
  `A` (par exemple `souk.mondomaine.ma`) vers l'IP publique de la VM.
- **Pas de domaine** : utilisez [sslip.io](https://sslip.io), gratuit et sans
  inscription. Pour l'IP `132.145.10.20`, le nom `132-145-10-20.sslip.io`
  pointe déjà vers elle.

Vérification (sur votre PC) : `nslookup souk.mondomaine.ma` doit afficher l'IP de la VM.

## 4. Première connexion et mise à jour du système

Depuis WSL :

```bash
ssh ubuntu@IP_PUBLIQUE
```

Puis, sur le serveur :

```bash
sudo apt update && sudo apt full-upgrade -y
# Mises à jour de sécurité installées automatiquement chaque jour
sudo apt install -y unattended-upgrades git
sudo dpkg-reconfigure -plow unattended-upgrades   # répondre « Oui »
sudo reboot
```

Reconnectez-vous une minute plus tard (`ssh ubuntu@IP_PUBLIQUE`).

## 5. Pare-feu de la VM : ports 22, 80 et 443 uniquement

Les images Ubuntu d'Oracle Cloud ont **déjà** un pare-feu `iptables` qui refuse
tout sauf SSH (22). On y ajoute 80 et 443, **avant** d'installer Docker.

> Pourquoi pas `ufw` ? Sur Oracle Cloud, il entre en conflit avec les règles
> `iptables` fournies par Oracle (dont certaines sont nécessaires au
> fonctionnement de la VM). On garde donc leur outil, `netfilter-persistent`.

```bash
# Les règles actuelles : on cherche la ligne "REJECT ... reject-with icmp-host-prohibited"
sudo iptables -L INPUT -n --line-numbers

# On autorise 80 et 443 (TCP) et 443 (UDP), AVANT cette ligne REJECT (insertion en tête)
sudo iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -I INPUT 1 -p udp --dport 443 -j ACCEPT

# Les règles survivent au redémarrage
sudo netfilter-persistent save

# Vérification : 22 (déjà là), 80, 443 acceptés, puis REJECT pour tout le reste
sudo iptables -L INPUT -n --line-numbers
```

> Docker et le pare-feu : un port **publié** par Docker (`ports:` dans le
> compose) passe par ses propres règles et **contourne** la chaîne INPUT
> ci-dessus. Voilà pourquoi `docker-compose.prod.yml` ne publie que les ports
> de Caddy : Oracle et PHP n'ont aucun port publié, il n'y a donc rien à contourner.

## 6. Installer Docker (dépôt officiel, version ARM64)

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Utiliser docker sans sudo (prend effet à la prochaine connexion)
sudo usermod -aG docker "$USER"
exit
```

Reconnectez-vous, puis vérifiez :

```bash
docker run --rm hello-world     # "Hello from Docker!" ; architecture : uname -m → aarch64
docker compose version
```

## 7. Cloner et déployer

```bash
git clone https://github.com/taha654/souk-atlas.git
cd souk-atlas
./deploy.sh
```

`deploy.sh` pose deux questions (nom de domaine, email pour Let's Encrypt), puis :

1. crée le **`.env` du serveur** (droits `600`), avec des mots de passe Oracle
   **générés sur le serveur** (30 caractères aléatoires, jamais affichés). Votre
   `.env` local n'est jamais utilisé ni copié ;
2. construit l'image PHP **en ARM64, sur le serveur** (10 à 15 minutes la première fois) ;
3. lance Oracle, PHP et Caddy ; au tout premier démarrage, Oracle crée la base et
   installe le schéma avec les données de démonstration (quelques minutes) ;
4. vérifie que le site répond ;
5. installe les tâches planifiées (sauvegarde à 2 h 30 UTC, réinitialisation à 3 h UTC).

Pour un lancement sans questions :
`DOMAINE=souk.mondomaine.ma ACME_EMAIL=moi@exemple.ma ./deploy.sh`

Ouvrez ensuite `https://VOTRE_DOMAINE` : Caddy obtient le certificat à la
première visite (quelques secondes).

## 8. Vérifier la sécurité

Depuis **votre PC** (WSL) :

```bash
# HTTPS et en-têtes : HSTS, CSP, pas de version de serveur
curl -sI https://VOTRE_DOMAINE | grep -iE 'strict-transport|content-security|server|x-frame'
# HTTP redirige vers HTTPS (308)
curl -sI http://VOTRE_DOMAINE | head -3
# Oracle et PHP injoignables (doit échouer : "timed out" ou "refused")
nc -vz -w 5 IP_PUBLIQUE 1521
nc -vz -w 5 IP_PUBLIQUE 8000
# Cookie de session : doit contenir "secure; HttpOnly; SameSite=Lax"
curl -sI https://VOTRE_DOMAINE/connexion | grep -i set-cookie
```

Sur le **serveur** :

```bash
# Seuls 22, 80 et 443 écoutent sur l'extérieur
sudo ss -tlnp | grep -vE '127.0.0.1|::1'
# Une erreur PHP n'est jamais affichée : APP_ENV=prod et display_errors=Off
docker compose -f docker-compose.prod.yml exec php php -i | grep -E '^display_errors|^opcache.enable '
```

## 9. Le mode démonstration

Avec `DEMO_MODE=1` (valeur par défaut dans le `.env` créé par `deploy.sh`) :

| Mesure | Où |
|---|---|
| Bandeau « Site de démonstration — données fictives, réinitialisées chaque nuit » sur chaque page | `app/Views/layouts/principal.php` |
| Comptes de démo affichés sur la page de connexion (mot de passe `Demo1234!`) | `app/Views/auth/connexion.php` |
| L'admin ne peut ni modifier les comptes (désactivation, changement de rôle) ni créer, renommer ou supprimer des catégories | `AdminController` + `App\Services\ModeDemo` |
| Photos : 2 Mo au plus, 10 par compte, 300 sur tout le site | `App\Services\ModeDemo` |
| Chaque nuit : base remise à zéro, photos et emails simulés effacés | `deploy/reinitialiser_demo.sh` (cron) |

Les limites sont dans `app/config.php` (clé `demo`).

```bash
# Réinitialiser tout de suite (1 à 2 minutes de coupure)
./deploy/reinitialiser_demo.sh
# Journal des réinitialisations nocturnes
tail -n 30 ~/souk-journaux/reinitialisation.log
```

**Quitter le mode démo** (vrai site) : dans `.env`, mettre `DEMO_MODE=0`, puis
`./deploy.sh`. La réinitialisation nocturne ne fait alors plus rien (elle vérifie
la valeur dans le conteneur), et les comptes de démo doivent être supprimés ou
recevoir de nouveaux mots de passe.

## 10. Mettre à jour le site

Sur votre PC : commit et push comme d'habitude. Puis sur le serveur :

```bash
cd ~/souk-atlas
./deploy.sh
```

Le script fait `git pull`, reconstruit l'image, ne redémarre que ce qui a changé
et garde la base, les photos et les certificats (volumes Docker).

> Un changement de schéma (`database/migrations/`) n'est pas appliqué
> automatiquement à une base existante. En mode démo, la réinitialisation de la
> nuit réinstalle tout depuis `database/` : lancer `./deploy/reinitialiser_demo.sh`
> suffit. Sinon, appliquer la migration :
> `docker compose -f docker-compose.prod.yml exec -T oracle bash -c 'sqlplus -s "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1" @/opt/souk/database/migrations/<fichier>.sql'`

## 11. Sauvegardes

`deploy/sauvegarder.sh` (chaque nuit à 2 h 30 UTC, avant la réinitialisation)
produit dans `~/souk-sauvegardes/` (droits `700`) :

| Fichier | Contenu |
|---|---|
| `souk_DATE.dmp.gz` | Export **Data Pump** du schéma SOUK (tables, données, packages, triggers, jobs) |
| `uploads_DATE.tar.gz` | Photos envoyées par les visiteurs |
| `env_DATE` | Le `.env` du serveur (mots de passe : indispensable pour restaurer) |

Les fichiers de plus de 7 jours sont supprimés.

```bash
# Sauvegarde immédiate
./deploy/sauvegarder.sh
ls -lh ~/souk-sauvegardes/

# Copie HORS du serveur (à lancer depuis votre PC) : une sauvegarde qui reste
# sur la même machine disparaît avec elle
scp -r ubuntu@IP_PUBLIQUE:souk-sauvegardes ./souk-sauvegardes-$(date +%F)

# Restauration (remplace le schéma actuel ; l'archive des photos est facultative)
./deploy/restaurer.sh ~/souk-sauvegardes/souk_2026-11-02_0230.dmp.gz ~/souk-sauvegardes/uploads_2026-11-02_0230.tar.gz
```

En complément, Oracle Cloud offre 5 sauvegardes gratuites de volumes
(**Block Storage → Boot Volumes → Create Manual Backup**) : une image de tout le disque.

> En mode démo, ces sauvegardes ont peu d'intérêt (la base revient chaque nuit
> aux données de démonstration) : elles servent surtout le jour où le site
> quitte le mode démo, et à garder le `.env`.

## 12. Commandes utiles

```bash
cd ~/souk-atlas
alias dcp='docker compose -f docker-compose.prod.yml'   # à mettre dans ~/.bashrc

dcp ps                        # état des conteneurs (Oracle doit être "healthy")
dcp logs -f caddy             # certificats, requêtes refusées
dcp logs -f php               # erreurs PHP (jamais affichées aux visiteurs)
dcp logs -f oracle
dcp restart php
dcp exec oracle bash -c 'sqlplus "$APP_USER/$APP_USER_PASSWORD@//localhost/FREEPDB1"'
crontab -l                    # tâches planifiées
docker system df              # place occupée par Docker
```

## 13. Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Le navigateur n'arrive pas à joindre le site | Port fermé dans la Security List (étape 2) ou dans `iptables` (étape 5) | Vérifier les deux : il faut **les deux** ouverts |
| Certificat refusé, `dcp logs caddy` parle de « challenge failed » | Le domaine ne pointe pas encore vers la VM, ou port 80 fermé | `nslookup` (étape 3) ; Caddy réessaie tout seul |
| Erreur 502 | PHP arrêté ou en train de redémarrer (réinitialisation de 3 h) | `dcp ps`, `dcp logs php` |
| `deploy.sh` : « Oracle n'est pas prêt » | Premier démarrage long, ou mémoire | `dcp logs oracle` |
| « permission denied » sur docker | Groupe `docker` pas encore pris en compte | Se déconnecter et se reconnecter |

## Vérifier l'ARM64 depuis votre PC (avant de déployer)

Docker Desktop sait **émuler** un processeur ARM64 (QEMU). Sous WSL :

```bash
./deploy/verifier_arm64.sh
```

Le script construit l'image de production en `linux/arm64` (moteur C++ et ses
tests CTest, Instant Client ARM64, OCI8, GD), puis lance dans ce conteneur ARM64 :
la liste des extensions, le moteur C++, une vraie connexion à votre base Oracle
locale, et un traitement d'image GD. Comptez 15 à 30 minutes : l'émulation est lente.
