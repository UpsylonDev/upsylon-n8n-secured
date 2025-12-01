# Guide de Migration vers PostgreSQL Managée - Render.io

## ✅ Étape 1 : Préparation (TERMINÉE)

- [x] Sauvegarde de l'ancienne configuration → `render.private-db.yaml.backup`
- [x] Application de la nouvelle configuration → `render.yaml`
- [x] Fichiers de documentation créés

## 🚀 Étape 2 : Créer la base PostgreSQL dans Render (ACTION REQUISE)

### Instructions détaillées

1. **Ouvrez votre Dashboard Render** : https://dashboard.render.com

2. **Créez une nouvelle base PostgreSQL** :

   - Cliquez sur **"New +"** en haut à droite
   - Sélectionnez **"PostgreSQL"**

3. **Configurez la base de données** :

   ```
   Name:           n8n-postgres
   Database:       n8n
   User:           n8n
   Region:         [Choisissez la MÊME région que votre service n8n-secured]
   PostgreSQL Version: 15
   Plan:           Starter ($7/mois) ou Free (pour tester)
   ```

4. **Créez la base** :

   - Cliquez sur **"Create Database"**
   - Attendez que le statut passe à **"Available"** (2-3 minutes)

5. **Notez les informations** (optionnel, Render les injectera automatiquement) :
   - Internal Database URL
   - External Database URL
   - Host
   - Port
   - Database
   - Username
   - Password

## 📤 Étape 3 : Pousser la nouvelle configuration (PRÊT)

Une fois la base de données créée dans Render, exécutez ces commandes :

```powershell
# Ajouter tous les fichiers
git add render.yaml RENDER_TROUBLESHOOTING.md UPDATE_GUIDE.md WORKFLOWS_VERSIONING.md TROUBLESHOOTING.md

# Commiter
git commit -m "feat: Migrate to Render Managed PostgreSQL for guaranteed data persistence"

# Pousser
git push
```

## 🔄 Étape 4 : Vérification du déploiement

Après le push, Render va automatiquement redéployer votre application.

### Vérifications à faire :

1. **Dashboard Render** → Service `n8n-secured` → **Logs**

   - Attendez que le déploiement soit terminé
   - Vérifiez qu'il n'y a pas d'erreurs de connexion PostgreSQL

2. **Testez l'accès** :

   - Ouvrez votre URL Render : `https://votre-app.onrender.com`
   - Vous devriez voir la page `/setup` (normal, c'est une nouvelle base)

3. **Configurez n8n** :
   - Créez votre compte propriétaire
   - Configurez vos credentials

## 📥 Étape 5 : Restaurer vos workflows (si vous en aviez)

Si vous aviez des workflows à restaurer :

```powershell
# Option 1 : Import manuel
# 1. Allez dans n8n
# 2. Pour chaque workflow dans workflows/production/
# 3. Menu → Import from File

# Option 2 : Script automatisé (nécessite que n8n soit configuré)
.\scripts\import-workflows.ps1 -N8nHost "https://votre-app.onrender.com" -Force
```

## ✅ Checklist de Migration

### Avant le déploiement

- [x] Configuration `render.yaml` mise à jour
- [ ] Base PostgreSQL créée dans Render Dashboard
- [ ] Base PostgreSQL en statut "Available"

### Déploiement

- [ ] `git add` et `git commit` exécutés
- [ ] `git push` exécuté
- [ ] Déploiement Render terminé sans erreur

### Après le déploiement

- [ ] Application accessible
- [ ] Page `/setup` affichée (normal)
- [ ] Compte propriétaire créé
- [ ] Workflows importés (si applicable)
- [ ] Test d'un workflow simple

### Vérification de persistance

- [ ] Créer un workflow de test
- [ ] Redéployer l'application (push un petit changement)
- [ ] Vérifier que le workflow est toujours là ✅

## 🎯 Avantages de cette migration

✅ **Persistance garantie** - Vos données ne seront plus jamais perdues
✅ **Backups automatiques** - Render sauvegarde quotidiennement
✅ **Haute disponibilité** - 99.95% uptime
✅ **Monitoring** - Métriques de performance incluses
✅ **Scaling** - Possibilité d'augmenter les ressources facilement

## 🔙 Rollback (si nécessaire)

Si vous rencontrez des problèmes, vous pouvez revenir en arrière :

```powershell
# Restaurer l'ancienne configuration
Copy-Item render.private-db.yaml.backup render.yaml -Force

# Commiter et pousser
git add render.yaml
git commit -m "revert: Rollback to private PostgreSQL service"
git push
```

## 🆘 Dépannage

### La base PostgreSQL ne se crée pas

- Vérifiez votre plan Render (Free tier a des limitations)
- Essayez une autre région
- Contactez le support Render

### Erreur de connexion après déploiement

- Vérifiez que la base est en statut "Available"
- Vérifiez que le nom de la base dans `render.yaml` correspond (`n8n-postgres`)
- Consultez les logs : Dashboard → Service n8n-secured → Logs

### Les workflows ne s'importent pas

- Vérifiez que vous avez créé le compte propriétaire
- Vérifiez les credentials dans le script d'import
- Importez manuellement via l'interface

## 📚 Ressources

- [Documentation Render PostgreSQL](https://render.com/docs/databases)
- [RENDER_TROUBLESHOOTING.md](RENDER_TROUBLESHOOTING.md)
- [WORKFLOWS_VERSIONING.md](WORKFLOWS_VERSIONING.md)

---

**Prochaine étape** : Créez la base PostgreSQL dans le Dashboard Render, puis exécutez les commandes Git ci-dessus.
