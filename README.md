# N8n local container

## Tuto :

`https://www.youtube.com/watch?v=4QdYfnJrLuE&list=PLTP6_OsD42BcfT_TyvDsJEomAc1lg5pSr`

## Quick : Si déjà installé

- docker-compose up -d
- `http://localhost:9000`

- update : docker pull docker.n8n.io/n8nio/n8n
- stop : docker-compose down

# n8n - Documentation Docker Complète

**✅ TOTALEMENT GRATUIT !**

- **Version Self-hosted (ce que tu installes)** : 100% gratuite, open-source, aucune limitation
- **Pas de frais cachés** : Aucun coût pour l'installation locale
- **Usage illimité** : Workflows, exécutions, utilisateurs - tout est illimité
- **Code open-source** : Disponible sur GitHub sous licence Apache 2.0

> ℹ️ Il existe une version Cloud payante, mais elle est optionnelle. En self-hosted, tout est gratuit !

---

## 🚀 Installation initiale

### Prérequis

- Docker Desktop installé et lancé
- Un terminal (CMD, PowerShell, ou Terminal selon ton OS)

### 1. Créer le dossier du projet

```bash
mkdir n8n-project
cd n8n-project
```

### 2. Configuration de l'environnement

Copiez le fichier d'exemple `.env.example` vers `.env` :

```bash
cp .env.example .env
```

Ouvrez le fichier `.env` et configurez votre projet :

```properties
# Nom unique pour votre projet (ex: mon-projet-client-a)
PROJECT_NAME=mon-projet-client-a

# Port unique pour ce projet (ex: 3001 si 3000 est déjà pris)
N8N_PORT=3001
```

### 3. Créer le fichier docker-compose.yml

Crée un fichier `docker-compose.yml` avec ce contenu :

```yaml
version: "3.8"

services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin@admin.com
      - N8N_BASIC_AUTH_PASSWORD=admin123
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
```

### 3. Lancer n8n

```bash
docker-compose up -d
```

Le `-d` signifie "détaché" (tourne en arrière-plan)

### 4. Accéder à l'interface

Ouvre ton navigateur : `http://localhost:3000` (ou le port défini dans `N8N_PORT`)

**Identifiants par défaut :**

- **User** : `admin`
- **Password** : `admin123`

---

## 📋 Commandes essentielles Docker

### Gestion de base

**Démarrer n8n**

```bash
docker-compose up -d
```

**Arrêter n8n**

```bash
docker-compose down
```

**Redémarrer n8n**

```bash
docker-compose restart
```

**Voir si n8n fonctionne**

```bash
docker ps
```

**Arrêter et supprimer TOUT (données incluses)**

```bash
docker-compose down -v
```

⚠️ **ATTENTION** : Cette commande supprime toutes tes données !

---

### Logs et débogage

**Voir les logs en temps réel**

```bash
docker-compose logs -f
```

(Appuie sur `Ctrl+C` pour quitter)

**Voir les dernières lignes de logs**

```bash
docker-compose logs --tail=100
```

**Voir les logs d'un service spécifique**

```bash
docker-compose logs n8n
```

---

### Maintenance

**Mettre à jour n8n vers la dernière version**

✅ **VOS DONNÉES SONT PRÉSERVÉES** lors d'une mise à jour ! Les volumes Docker (`n8n_data` et `postgres_data`) restent intacts.

**Méthode 1 : Script automatisé (recommandé)**

```powershell
# Mise à jour avec sauvegarde automatique
.\scripts\update-n8n.ps1

# Mise à jour rapide sans backup (vos données restent sûres)
.\scripts\update-n8n.ps1 -SkipBackup
```

**Méthode 2 : Manuelle**

```bash
# Exporter les workflows (recommandé)
.\scripts\export-workflows.ps1

# Mettre à jour
docker compose pull
docker compose up -d

# Vérifier
docker compose ps
```

> ⚠️ **IMPORTANT** : N'utilisez **JAMAIS** `docker compose down -v` car le flag `-v` supprime les volumes et donc vos données !

**Voir l'espace disque utilisé par Docker**

```bash
docker system df
```

**Nettoyer Docker (images inutilisées)**

```bash
docker system prune -a
```

**Voir les conteneurs (même arrêtés)**

```bash
docker ps -a
```

---

---

## 🆕 Créer un nouveau projet (Base de données vide)

Pour créer un nouveau projet n8n complètement indépendant avec une base de données vide :

1. **Créer un nouveau dossier** sur votre ordinateur (ex: `mon-nouveau-projet`)
2. **Copier** les fichiers `docker-compose.yml` et `.env` dans ce nouveau dossier
3. **Lancer** le nouveau projet :
   ```bash
   cd mon-nouveau-projet
   cp .env.example .env
   # Modifiez PROJECT_NAME et N8N_PORT dans .env
   docker-compose up -d
   ```

Docker créera automatiquement des conteneurs nommés selon votre `PROJECT_NAME` (ex: `mon-projet-n8n`) et utilisera le port défini. Vos données seront totalement isolées.

---

## 📁 Gestion des données

### Où sont stockées les données ?

Les données de n8n (workflows, credentials, exécutions) sont stockées dans un **volume Docker** nommé `n8n_data`.

**Voir tous les volumes**

```bash
docker volume ls
```

**Inspecter le volume n8n**

```bash
docker volume inspect n8n-project_n8n_data
```

**Sauvegarder les données**

```bash
# Créer un dossier de backup
mkdir backup

# Copier les données du volume
docker run --rm -v n8n-project_n8n_data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/n8n-backup.tar.gz -C /data .
```

**Restaurer les données**

```bash
docker run --rm -v n8n-project_n8n_data:/data -v $(pwd)/backup:/backup alpine tar xzf /backup/n8n-backup.tar.gz -C /data
```

---

## 📝 Versionnement des Workflows

### Pourquoi versionner vos workflows ?

Les workflows n8n sont stockés dans la base de données PostgreSQL et **ne sont pas automatiquement sauvegardés dans Git**. Pour assurer la traçabilité et la collaboration, ce projet inclut un système de versionnement des workflows.

### Export manuel

1. Dans n8n, ouvrez votre workflow
2. Cliquez sur `...` → `Download`
3. Sauvegardez le fichier JSON dans `workflows/production/`
4. Commitez :
   ```bash
   git add workflows/
   git commit -m "feat(workflow): Add email automation"
   git push
   ```

### Export automatique (recommandé)

Utilisez le script PowerShell fourni :

```powershell
# Exporter tous les workflows actifs
.\scripts\export-workflows.ps1

# Exporter vers staging
.\scripts\export-workflows.ps1 -Environment staging
```

### Import de workflows

Pour importer des workflows depuis Git vers n8n :

```powershell
# Importer depuis production
.\scripts\import-workflows.ps1

# Mettre à jour les workflows existants
.\scripts\import-workflows.ps1 -Force
```

### Structure des workflows

```
workflows/
├── production/     # Workflows actifs en production
├── staging/        # Workflows en test
├── templates/      # Templates réutilisables
└── README.md       # Documentation
```

> 📖 **Documentation complète** : Consultez [WORKFLOWS_VERSIONING.md](WORKFLOWS_VERSIONING.md) pour plus de détails

---

## 🛠️ Dépannage

### n8n ne démarre pas

```bash
# 1. Vérifier les logs pour voir l'erreur
docker-compose logs

# 2. Vérifier que Docker Desktop est bien lancé
docker --version

# 3. Redémarrer complètement
docker-compose down
docker-compose up -d
```

### Port 5678 déjà utilisé

Si le port 5678 est déjà utilisé par une autre application, modifie le port dans `docker-compose.yml` :

```yaml
ports:
  - "5679:5678" # Utilise le port 5679 à la place
```

Puis accède à `http://localhost:5679`

### Réinitialiser complètement n8n

```bash
# Arrêter et supprimer tout
docker-compose down -v

# Supprimer l'image
docker rmi docker.n8n.io/n8nio/n8n

# Redémarrer proprement
docker-compose up -d
```

### Erreur "Cannot connect to Docker daemon"

- Vérifie que **Docker Desktop est lancé**
- Sur Windows : regarde dans la barre des tâches
- Sur Mac : regarde dans la barre de menu
- Redémarre Docker Desktop si nécessaire

---

## 🔐 Sécurité

### Changer le mot de passe

Modifie cette ligne dans `docker-compose.yml` :

```yaml
- N8N_BASIC_AUTH_PASSWORD=ton_nouveau_mot_de_passe_securise
```

Puis redémarre :

```bash
docker-compose down
docker-compose up -d
```

### Désactiver l'authentification (déconseillé)

```yaml
- N8N_BASIC_AUTH_ACTIVE=false
```

⚠️ Ne fais ça que pour du développement local !

### Variables d'environnement utiles

```yaml
environment:
  - N8N_BASIC_AUTH_ACTIVE=true
  - N8N_BASIC_AUTH_USER=admin
  - N8N_BASIC_AUTH_PASSWORD=admin123
  - N8N_HOST=localhost
  - N8N_PORT=5678
  - N8N_PROTOCOL=http
  - NODE_ENV=production
  - WEBHOOK_URL=http://localhost:5678/
  - EXECUTIONS_DATA_PRUNE=true
  - EXECUTIONS_DATA_MAX_AGE=168 # Supprime les exécutions après 7 jours
```

---

## 🎯 Configuration avancée avec MongoDB

Si tu veux utiliser MongoDB (compatible avec ton stack !) au lieu de SQLite :

```yaml
version: "3.8"

services:
  mongodb:
    image: mongo:7
    container_name: n8n_mongodb
    restart: unless-stopped
    environment:
      - MONGO_INITDB_ROOT_USERNAME=root
      - MONGO_INITDB_ROOT_PASSWORD=password123
    volumes:
      - n8n_mongodb_data:/data/db
    ports:
      - "27017:27017"

  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=mongodb
      - DB_MONGODB_CONNECTION_URL=mongodb://root:password123@mongodb:27017/n8n?authSource=admin
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin123
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - mongodb

volumes:
  n8n_data:
  n8n_mongodb_data:
```

**Commandes spécifiques MongoDB :**

```bash
# Accéder au shell MongoDB
docker exec -it n8n_mongodb mongosh -u root -p password123

# Sauvegarder MongoDB
docker exec n8n_mongodb mongodump --uri="mongodb://root:password123@localhost:27017/n8n?authSource=admin" --out=/dump

# Restaurer MongoDB
docker exec n8n_mongodb mongorestore --uri="mongodb://root:password123@localhost:27017/n8n?authSource=admin" /dump
```

---

## 🤖 Pourquoi n8n pour l'apprentissage AI en 2025 ?

### Intégrations AI natives

- ✅ **OpenAI** : GPT-4, GPT-3.5, DALL-E, Whisper
- ✅ **Anthropic Claude** : Claude 3 Opus, Sonnet, Haiku
- ✅ **Google AI** : Gemini, PaLM
- ✅ **Mistral AI** : Modèles open-source
- ✅ **Ollama** : Exécute des LLM localement
- ✅ **Hugging Face** : Accès à des milliers de modèles
- ✅ **LangChain** : Framework pour créer des agents
- ✅ **Pinecone / Qdrant** : Bases de données vectorielles

### Fonctionnalités clés pour l'AI

1. **Agents AI** : Crée des agents qui peuvent utiliser des outils
2. **RAG (Retrieval Augmented Generation)** : Combine LLM avec tes données
3. **Mémoire conversationnelle** : Stocke le contexte des conversations
4. **Embeddings** : Crée des représentations vectorielles de texte
5. **Code personnalisé** : JavaScript/TypeScript pour logique complexe
6. **API REST** : Intègre avec ton stack Node.js/Express
7. **Webhooks** : Déclenche des workflows depuis tes apps
8. **Scheduling** : Lance des tâches automatiquement

### Avantages pour ton apprentissage

- **Interface visuelle** : Comprends le flux de données facilement
- **Templates prêts** : Des centaines d'exemples à explorer
- **Pas de configuration complexe** : Tout marche out-of-the-box
- **Documentation riche** : Guides et tutoriels
- **Communauté active** : Forum et Discord

---

## 💡 Premiers pas recommandés

### Jour 1 : Découverte

1. ✅ Lance n8n avec Docker
2. ✅ Explore l'interface
3. ✅ Crée un workflow "Hello World" simple
4. ✅ Teste le node "HTTP Request"

### Jour 2 : Premier workflow AI

1. ✅ Crée un compte OpenAI (free tier disponible)
2. ✅ Configure les credentials OpenAI dans n8n
3. ✅ Crée un chatbot simple avec GPT-4
4. ✅ Teste différents prompts

### Jour 3 : Workflow avancé

1. ✅ Ajoute une base de données (MongoDB ou PostgreSQL)
2. ✅ Crée un système de mémoire conversationnelle
3. ✅ Utilise des webhooks pour déclencher des workflows

### Jour 4 : Agent AI

1. ✅ Explore les templates d'agents
2. ✅ Crée un agent qui peut utiliser des outils (web search, calculator)
3. ✅ Intègre LangChain

### Jour 5 : RAG System

1. ✅ Configure Pinecone ou Qdrant
2. ✅ Crée des embeddings de tes documents
3. ✅ Construis un chatbot qui répond sur tes données

---

## 📚 Ressources d'apprentissage

### Documentation officielle

- **Docs n8n** : https://docs.n8n.io
- **Templates** : https://n8n.io/workflows
- **Intégrations** : https://n8n.io/integrations

### Communauté

- **Forum** : https://community.n8n.io
- **Discord** : https://discord.gg/n8n
- **GitHub** : https://github.com/n8n-io/n8n

### Tutoriels AI spécifiques

- **oAuth avec n8n** : https://docs.n8n.io/integrations/builtin/credentials/google/oauth-single-service/#finish-your-n8n-credential
- **ChatGPT avec n8n** : https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.openai/
- **LangChain** : https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain/
- **Agents AI** : https://blog.n8n.io/ai-agents/

### Chaînes YouTube recommandées

- **n8n Official** : Tutoriels officiels
- **AI Automation** : Cas d'usage AI avec n8n

---

## 🎓 Exemples de projets à construire

### Débutant

- ✅ Chatbot simple avec GPT-4
- ✅ Générateur d'images avec DALL-E
- ✅ Transcription audio avec Whisper
- ✅ Résumé automatique d'articles web

### Intermédiaire

- ✅ Assistant personnel avec mémoire
- ✅ Système de support client automatisé
- ✅ Analyseur de sentiment des emails
- ✅ Générateur de contenu pour réseaux sociaux

### Avancé

- ✅ Agent AI avec accès à des outils externes
- ✅ RAG system sur ta base de connaissances
- ✅ Pipeline de traitement de documents
- ✅ Système multi-agents collaboratifs

---

## ✅ Checklist de démarrage

### Installation

- [ ] Docker Desktop installé et lancé
- [ ] Dossier `n8n-project` créé
- [ ] Fichier `docker-compose.yml` créé
- [ ] `docker-compose up -d` exécuté avec succès
- [ ] Interface accessible sur `http://localhost:5678`
- [ ] Connexion avec admin/admin123 réussie

### Configuration

- [ ] Mot de passe changé (sécurité)
- [ ] Compte OpenAI créé (ou autre LLM)
- [ ] Credentials AI configurés dans n8n
- [ ] Premier workflow créé et testé

### Apprentissage

- [ ] Documentation n8n parcourue
- [ ] Au moins 3 templates explorés
- [ ] Premier chatbot AI fonctionnel
- [ ] Webhook testé avec succès

---

## 🚀 Prochaines étapes : MCP et Agents

### Model Context Protocol (MCP)

n8n supporte MCP pour connecter des LLM à des sources de données externes :

- **Qu'est-ce que MCP ?** : Protocole standardisé pour que les LLM accèdent à des outils
- **Usage dans n8n** : Crée des agents qui peuvent utiliser tes APIs
- **Exemples** : Agent qui lit tes emails, accède à ta base de données, cherche sur le web

### Créer ton premier Agent

```
Workflow type: Agent AI
1. Trigger (Webhook ou Chat)
2. Agent Node (LangChain)
   - Configure le LLM (GPT-4, Claude)
   - Ajoute des outils (Calculator, Web Search, Database)
3. Mémoire (Buffer Memory)
4. Response
```

---

## 💪 Commandes Docker rapides (Cheat Sheet)

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Logs
docker-compose logs -f

# Redémarrer
docker-compose restart

# Status
docker ps

# Mettre à jour
docker-compose pull && docker-compose up -d

# Nettoyer
docker system prune -a

# Sauvegarder
docker run --rm -v n8n-project_n8n_data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/n8n-backup.tar.gz -C /data .
```

---

## 🎉 Tu es prêt !

**Félicitations !** Tu as maintenant :

- ✅ n8n installé et configuré
- ✅ Toutes les commandes Docker essentielles
- ✅ Une roadmap d'apprentissage AI
- ✅ Des ressources pour progresser

**Prochaine étape** : Lance `docker-compose up -d` et commence à créer ton premier workflow AI !

---

---

## 🚀 Déploiement sur Render.io

Ce projet est configuré pour être déployé facilement sur [Render.io](https://render.com).

### Configuration

1.  **Créer un compte sur Render.io**.
2.  **Créer un nouveau Blueprint** :
    - Connectez votre dépôt GitHub à Render.
    - Render détectera automatiquement le fichier `render.yaml`.
    - Cliquez sur "Apply".

> ⚠️ **Note Importante** : Le nom du service dans `render.yaml` (`name: n8n-secured`) est **statique**. Si vous changez le nom de votre projet, vous devez modifier manuellement ce fichier, car Render ne supporte pas les variables dynamiques pour les noms de services.

### Déploiement Continu (CD)

Le fichier `.github/workflows/deploy.yml` permet de déclencher un déploiement à chaque push sur la branche `main`.

Pour l'activer :

1.  Allez dans votre dashboard Render, sélectionnez votre service **n8n**.
2.  Allez dans **Settings** > **Deploy Hook**.
3.  Copiez l'URL du Deploy Hook.
4.  Allez dans votre dépôt GitHub > **Settings** > **Secrets and variables** > **Actions**.
5.  Créez un nouveau secret nommé `RENDER_DEPLOY_HOOK` et collez l'URL.

Désormais, chaque modification sur `main` redéploiera automatiquement votre instance n8n.

---

**Version** : 1.0  
**Dernière mise à jour** : Octobre 2025  
**Auteur** : Documentation personnalisée pour apprentissage AI avec n8n

💡 **Astuce** : Garde ce README à portée de main et n'hésite pas à le compléter avec tes propres découvertes !
