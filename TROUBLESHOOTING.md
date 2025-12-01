# Guide de Dépannage - n8n Secured

## 🔴 Problème : Perte de données après un commit Git

### Symptômes

- Vos workflows n8n disparaissent après un `git commit`, `git checkout` ou `git pull`
- Vous devez reconfigurer n8n à chaque fois
- Les credentials sont perdus

### Cause

Le fichier `.env` était versionné dans Git. Quand Git modifie ce fichier (lors d'un checkout, merge, etc.), les variables d'environnement changent, notamment :

- `PROJECT_NAME` : change le nom des volumes Docker
- `POSTGRES_PASSWORD` : change les credentials de la base de données

Docker crée alors de **nouveaux volumes** avec des noms différents, et vos données restent dans les anciens volumes inaccessibles.

### Solution ✅

#### 1. Le fichier `.env` est maintenant dans `.gitignore`

Le fichier `.env` ne sera plus versionné dans Git. Cela signifie :

- ✅ Vos variables d'environnement restent stables
- ✅ Les volumes Docker gardent les mêmes noms
- ✅ Vos données persistent entre les commits

#### 2. Retrouver vos anciennes données

Si vous avez perdu des données, elles sont probablement encore dans un ancien volume Docker :

```powershell
# Lister tous les volumes Docker
docker volume ls

# Inspecter un volume spécifique pour voir son contenu
docker volume inspect <nom_du_volume>

# Si vous trouvez vos anciennes données, vous pouvez les copier
docker run --rm -v <ancien_volume>:/source -v <nouveau_volume>:/dest alpine cp -r /source/. /dest/
```

#### 3. Nettoyer les anciens volumes (optionnel)

⚠️ **ATTENTION** : Cette commande supprime TOUS les volumes non utilisés !

```powershell
# Voir les volumes non utilisés
docker volume ls -f dangling=true

# Supprimer les volumes non utilisés (ATTENTION : perte de données !)
docker volume prune
```

## 🔄 Bonnes Pratiques

### Avant de commencer

1. Copiez `.env.example` vers `.env`
2. Configurez vos variables dans `.env`
3. Ne commitez **JAMAIS** le fichier `.env`

### Sauvegarde des données

Pour sauvegarder vos données n8n :

```powershell
# Arrêter les conteneurs
docker compose down

# Sauvegarder le volume n8n_data
docker run --rm -v upsylon-n8n-secured_n8n_data:/data -v ${PWD}/backup:/backup alpine tar czf /backup/n8n_backup_$(date +%Y%m%d).tar.gz -C /data .

# Sauvegarder le volume postgres_data
docker run --rm -v upsylon-n8n-secured_postgres_data:/data -v ${PWD}/backup:/backup alpine tar czf /backup/postgres_backup_$(date +%Y%m%d).tar.gz -C /data .

# Redémarrer
docker compose up -d
```

### Restauration des données

```powershell
# Arrêter les conteneurs
docker compose down

# Restaurer n8n_data
docker run --rm -v upsylon-n8n-secured_n8n_data:/data -v ${PWD}/backup:/backup alpine sh -c "cd /data && tar xzf /backup/n8n_backup_YYYYMMDD.tar.gz"

# Restaurer postgres_data
docker run --rm -v upsylon-n8n-secured_postgres_data:/data -v ${PWD}/backup:/backup alpine sh -c "cd /data && tar xzf /backup/postgres_backup_YYYYMMDD.tar.gz"

# Redémarrer
docker compose up -d
```

## 📋 Vérifications

### Vérifier que vos volumes sont bien créés

```powershell
docker volume ls | Select-String "n8n"
```

Vous devriez voir :

```
upsylon-n8n-secured_n8n_data
upsylon-n8n-secured_postgres_data
```

### Vérifier que .env n'est pas dans Git

```powershell
git ls-files .env
```

Cette commande ne doit **rien** retourner.

### Vérifier l'état de vos conteneurs

```powershell
docker compose ps
```

Tous les conteneurs doivent être "Up" et "healthy".

## 🆘 Autres Problèmes Courants

### Erreur : "database does not exist"

```powershell
docker compose down
docker volume rm upsylon-n8n-secured_postgres_data
docker compose up -d
```

### Erreur : "password authentication failed"

Vérifiez que les variables dans `.env` correspondent :

- `POSTGRES_PASSWORD` doit être la même dans les sections `postgres` et `n8n`
- `POSTGRES_USER` doit être la même dans les sections `postgres` et `n8n`
- `POSTGRES_DB` doit être la même dans les sections `postgres` et `n8n`

### Les workflows sont là mais ne s'exécutent pas

```powershell
# Redémarrer n8n
docker compose restart n8n

# Vérifier les logs
docker compose logs -f n8n
```
