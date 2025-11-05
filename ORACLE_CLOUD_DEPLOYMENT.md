# Oracle Cloud Deployment Guide

This guide explains how to deploy the n8n + n8n-runner stack to Oracle Cloud Infrastructure (OCI).

## Prerequisites

- Oracle Cloud account (free tier available)
- Docker Hub image: `upiik/n8n-runner:latest` (public)
- SSH key pair for VM access (if using Compute option)

## Deployment Options

### Option 1: Oracle Container Instances (Recommended - Simplest)

Oracle Container Instances allows you to run Docker containers directly without managing VMs.

#### Steps

**1. Access OCI Console**
- Login to https://cloud.oracle.com
- Navigate: `Developer Services` → `Container Instances`

**2. Create Container Instance**
```
- Click "Create Container Instance"
- Name: n8n-stack
- Compartment: Select your compartment
- Shape: CI.Standard.E4.Flex (Always Free eligible)
- Networking: Public or private VCN based on needs
```

**3. Add Containers**

**Container 1 - n8n:**
- Image: `docker.n8n.io/n8nio/n8n:latest`
- Port: 5678
- Environment variables:
  - `N8N_BASIC_AUTH_ACTIVE=true`
  - `N8N_BASIC_AUTH_USER=your_username`
  - `N8N_BASIC_AUTH_PASSWORD=your_secure_password`
  - `GENERIC_TIMEZONE=Europe/Paris`

**Container 2 - n8n-runner:**
- Image: `upiik/n8n-runner:latest`
- Port: 3000

**4. Configure Networking**
- Create Security List with rules:
  - Ingress: Port 5678 (n8n UI)
  - Ingress: Port 3000 (n8n-runner API) - **Only if needed externally**
- Assign public IP address

**5. Launch**
- Review configuration
- Click "Create"
- Wait for containers to start

---

### Option 2: Compute Instance + Docker (More Control)

Deploy on a VM with full control over the environment.

#### 1. Create Compute Instance

**Via OCI Console:**
```
Compute → Instances → Create Instance

Configuration:
- Name: n8n-server
- Image: Oracle Linux 8 or Ubuntu 22.04
- Shape: VM.Standard.E2.1.Micro (Always Free eligible)
  - 1 OCPU, 1 GB RAM, 0.48 Gbps network
- Networking:
  - VCN: Create new or use existing
  - Subnet: Public subnet
  - Assign public IPv4 address: Yes
- Add SSH keys: Upload your public key
- Boot volume: 50 GB (default)
```

**Configure Security List (Ingress Rules):**
```
Source CIDR: 0.0.0.0/0 (or restrict to your IP)
- TCP port 22 (SSH)
- TCP port 5678 (n8n)
- TCP port 3000 (n8n-runner) - optional, internal only recommended
```

#### 2. Connect via SSH

```bash
ssh -i /path/to/your-key.pem opc@<YOUR_PUBLIC_IP>

# For Ubuntu images, use:
# ssh -i /path/to/your-key.pem ubuntu@<YOUR_PUBLIC_IP>
```

#### 3. Install Docker and Docker Compose

**For Oracle Linux 8:**
```bash
# Install Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version

# Logout and login again for group changes
exit
```

**For Ubuntu 22.04:**
```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again
exit
```

#### 4. Configure Firewall

**Oracle Linux (firewalld):**
```bash
sudo firewall-cmd --permanent --add-port=5678/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

**Ubuntu (ufw):**
```bash
sudo ufw allow 22/tcp
sudo ufw allow 5678/tcp
sudo ufw allow 3000/tcp
sudo ufw enable
```

#### 5. Deploy the Stack

```bash
# Create project directory
mkdir ~/n8n-stack && cd ~/n8n-stack

# Create docker-compose.yml
nano docker-compose.yml
```

**docker-compose.yml content:**
```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=change_this_password
      - GENERIC_TIMEZONE=Europe/Paris
      - WEBHOOK_URL=https://your-domain.com/
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      - n8n-runner

  n8n-runner:
    image: upiik/n8n-runner:latest
    container_name: n8n-runner
    restart: unless-stopped
    ports:
      - "3000:3000"

volumes:
  n8n_data:
```

**Launch services:**
```bash
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

#### 6. Access n8n

Open browser: `http://<YOUR_PUBLIC_IP>:5678`

---

### Option 3: Oracle Kubernetes Engine (OKE)

For production deployments requiring scalability and high availability.

#### Overview

OKE provides managed Kubernetes clusters with:
- Auto-scaling
- Load balancing
- Rolling updates
- Multi-zone deployment

#### Quick Start

**1. Create OKE Cluster**
```
Developer Services → Kubernetes Clusters (OKE) → Create Cluster
- Quick Create (recommended)
- Name: n8n-cluster
- Kubernetes version: Latest stable
- Node pool: 2-3 nodes, VM.Standard.E2.1.Micro
```

**2. Install kubectl and configure access**
```bash
# Follow OCI console instructions to download kubeconfig
oci ce cluster create-kubeconfig --cluster-id <cluster-ocid>

# Verify connection
kubectl get nodes
```

**3. Deploy using Helm or YAML manifests**

**Example Kubernetes deployment** (n8n-deployment.yaml):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: n8n

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: n8n-data
  namespace: n8n
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-runner
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n-runner
  template:
    metadata:
      labels:
        app: n8n-runner
    spec:
      containers:
      - name: n8n-runner
        image: upiik/n8n-runner:latest
        ports:
        - containerPort: 3000

---
apiVersion: v1
kind: Service
metadata:
  name: n8n-runner
  namespace: n8n
spec:
  selector:
    app: n8n-runner
  ports:
  - port: 3000
    targetPort: 3000

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n
  template:
    metadata:
      labels:
        app: n8n
    spec:
      containers:
      - name: n8n
        image: docker.n8n.io/n8nio/n8n
        ports:
        - containerPort: 5678
        env:
        - name: N8N_BASIC_AUTH_ACTIVE
          value: "true"
        - name: N8N_BASIC_AUTH_USER
          value: "admin"
        - name: N8N_BASIC_AUTH_PASSWORD
          value: "change_this_password"
        - name: GENERIC_TIMEZONE
          value: "Europe/Paris"
        volumeMounts:
        - name: n8n-data
          mountPath: /home/node/.n8n
      volumes:
      - name: n8n-data
        persistentVolumeClaim:
          claimName: n8n-data

---
apiVersion: v1
kind: Service
metadata:
  name: n8n
  namespace: n8n
spec:
  type: LoadBalancer
  selector:
    app: n8n
  ports:
  - port: 80
    targetPort: 5678
```

**Deploy:**
```bash
kubectl apply -f n8n-deployment.yaml

# Get LoadBalancer IP
kubectl get svc -n n8n n8n
```

---

## Security Best Practices

### 1. Enable n8n Authentication

**CRITICAL:** Never expose n8n without authentication.

```yaml
environment:
  - N8N_BASIC_AUTH_ACTIVE=true
  - N8N_BASIC_AUTH_USER=your_username
  - N8N_BASIC_AUTH_PASSWORD=your_secure_password_here
```

### 2. Secure n8n-runner API

The n8n-runner API has **NO authentication** by default. To secure it:

**Option A: Network isolation (Recommended)**
- Keep n8n-runner on private network
- Only allow access from n8n container
- Do NOT expose port 3000 publicly

**Option B: Add authentication middleware**

Modify `n8n-runner/n8n-runner.js` to add API key authentication:

```javascript
// Add at the top
const API_KEY = process.env.API_KEY || 'your-secret-key';

// Add middleware before routes
app.use((req, res, next) => {
  const authHeader = req.headers['x-api-key'];
  if (authHeader !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});
```

Then rebuild and push the image.

### 3. HTTPS/SSL Configuration

**Option A: OCI Load Balancer with SSL**
```
Networking → Load Balancers → Create Load Balancer
- Add SSL certificate
- Backend set: Point to n8n container/VM
- Listener: HTTPS (443) → HTTP (5678)
```

**Option B: Reverse proxy with Let's Encrypt**

Install Caddy or Nginx on the VM:

**Caddy (simplest):**
```bash
sudo yum install -y caddy

# Create Caddyfile
sudo nano /etc/caddy/Caddyfile
```

```
your-domain.com {
    reverse_proxy localhost:5678
}

api.your-domain.com {
    reverse_proxy localhost:3000
}
```

```bash
sudo systemctl enable caddy
sudo systemctl start caddy
```

Caddy automatically obtains and renews Let's Encrypt certificates.

### 4. Firewall Rules

**Restrict access by IP:**
```
Security List Ingress Rules:
- Source: YOUR_IP/32
- Protocol: TCP
- Port: 5678
```

**Block n8n-runner from internet:**
```
Only allow:
- Source: VCN CIDR (internal only)
- Protocol: TCP
- Port: 3000
```

### 5. Environment Variables Security

Never hardcode sensitive credentials in docker-compose.yml:

```bash
# Create .env file
nano .env
```

```env
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password
API_KEY=your_api_key_here
```

```yaml
# Reference in docker-compose.yml
environment:
  - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
  - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
```

```bash
# Secure the file
chmod 600 .env
```

---

## Cost Estimation

### Always Free Tier (Permanent Free)

Oracle Cloud offers generous Always Free resources:

**Compute:**
- 2x VM.Standard.E2.1.Micro instances
  - 1/8 OCPU, 1 GB RAM each
  - Sufficient for n8n + n8n-runner

**Storage:**
- 2x 50 GB boot volumes
- 200 GB total Block Storage
- 10 GB Object Storage

**Networking:**
- 10 TB outbound data transfer/month
- 1x public IPv4 address

**Container Instances:**
- Limited free tier hours/month

### Estimated Costs (Beyond Free Tier)

**Paid Compute (if needed):**
- VM.Standard.E4.Flex: ~$0.015/OCPU/hour
  - 2 OCPU, 8 GB RAM: ~$22/month
- VM.Standard.E2.2: ~$0.034/hour (~$25/month)

**Load Balancer:**
- ~$15-30/month (10 Mbps)

**Block Storage:**
- $0.0255/GB/month
- 100 GB: ~$2.55/month

**Recommendation:** Start with Always Free tier (1x E2.1.Micro) for testing. Upgrade if performance is insufficient.

---

## Backup and Data Persistence

### n8n Workflows Backup

**Option 1: Volume backup (recommended)**
```bash
# Stop containers
docker-compose stop

# Backup n8n data
docker run --rm \
  -v tests-n8n_n8n_data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restart
docker-compose start
```

**Option 2: OCI Block Volume Backup**
- Navigate: Block Storage → Block Volumes
- Select n8n_data volume
- Click "Create Block Volume Backup"
- Schedule: Daily/Weekly

**Option 3: Export workflows via n8n UI**
- Settings → Export workflows
- Save JSON files to Object Storage

### Restore from Backup

```bash
docker run --rm \
  -v tests-n8n_n8n_data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/n8n-backup-YYYYMMDD.tar.gz -C /data
```

---

## Monitoring and Logs

### View Container Logs

```bash
# All containers
docker-compose logs -f

# Specific container
docker-compose logs -f n8n
docker-compose logs -f n8n-runner

# Last 100 lines
docker-compose logs --tail=100 n8n
```

### OCI Logging Service

Enable container logging to OCI Logging:

**For Container Instances:**
- Automatically logged to OCI Logging service
- Navigate: Observability → Logging → Logs

**For Compute instances:**
```bash
# Install OCI Logging Agent
sudo yum install -y oracle-cloud-agent
sudo systemctl enable oracle-cloud-agent
sudo systemctl start oracle-cloud-agent
```

Configure log collection in OCI Console:
- Observability → Logging → Log Groups
- Create custom log for Docker containers

### Health Checks

**n8n health:**
```bash
curl http://localhost:5678/healthz
```

**n8n-runner health:**
```bash
curl http://localhost:3000/status
```

### OCI Monitoring

Create alarms for:
- CPU usage > 80%
- Memory usage > 80%
- Container restart count
- Disk usage > 85%

---

## Troubleshooting

### Container won't start

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs n8n-runner

# Restart specific container
docker-compose restart n8n-runner

# Rebuild and restart
docker-compose up -d --force-recreate
```

### Cannot access from browser

1. **Check Security List rules:**
   - Ingress rule for port 5678 exists
   - Source CIDR allows your IP

2. **Check firewall on VM:**
   ```bash
   sudo firewall-cmd --list-all
   ```

3. **Verify containers are running:**
   ```bash
   docker ps
   ```

4. **Test locally on VM:**
   ```bash
   curl http://localhost:5678
   ```

### Port already in use

```bash
# Find process using port
sudo lsof -i :5678
sudo lsof -i :3000

# Kill process
sudo kill -9 <PID>

# Or change port in docker-compose.yml
ports:
  - "5679:5678"  # Use different host port
```

### Out of disk space

```bash
# Check disk usage
df -h

# Clean Docker resources
docker system prune -a --volumes

# Remove old images
docker image prune -a
```

### n8n-runner cannot execute commands

1. **Check if pnpm/npm is installed in target project:**
   ```bash
   curl -X POST http://localhost:3000/run-command \
     -H "Content-Type: application/json" \
     -d '{"command":"which pnpm"}'
   ```

2. **Verify project path exists:**
   - Update hardcoded path in `n8n-runner.js:62` if needed

3. **Check file permissions:**
   - n8n-runner runs as node user (UID 1000)
   - Ensure target directory is accessible

---

## Production Checklist

Before going to production:

- [ ] Enable n8n authentication (N8N_BASIC_AUTH_ACTIVE=true)
- [ ] Set strong passwords/API keys
- [ ] Configure HTTPS/SSL
- [ ] Restrict n8n-runner to internal network only
- [ ] Set up automated backups
- [ ] Configure monitoring and alerts
- [ ] Document your deployment
- [ ] Test disaster recovery process
- [ ] Set up log aggregation
- [ ] Review security list rules (principle of least privilege)
- [ ] Enable OCI Audit logging
- [ ] Configure rate limiting on Load Balancer
- [ ] Set up DNS with your domain
- [ ] Test workflow execution end-to-end

---

## Additional Resources

**OCI Documentation:**
- Container Instances: https://docs.oracle.com/en-us/iaas/Content/container-instances/home.htm
- Compute: https://docs.oracle.com/en-us/iaas/Content/Compute/home.htm
- OKE: https://docs.oracle.com/en-us/iaas/Content/ContEng/home.htm

**n8n Documentation:**
- Official docs: https://docs.n8n.io/
- Docker setup: https://docs.n8n.io/hosting/installation/docker/
- Security: https://docs.n8n.io/hosting/security/

**Docker Documentation:**
- Docker Compose: https://docs.docker.com/compose/
- Dockerfile best practices: https://docs.docker.com/develop/dev-best-practices/

---

## Quick Reference Commands

```bash
# SSH to VM
ssh -i key.pem opc@<IP>

# Start stack
docker-compose up -d

# Stop stack
docker-compose down

# View logs
docker-compose logs -f

# Restart service
docker-compose restart n8n

# Update images
docker-compose pull
docker-compose up -d

# Backup
docker run --rm -v tests-n8n_n8n_data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/n8n-backup.tar.gz -C /data .

# Clean Docker
docker system prune -af --volumes

# Check disk space
df -h

# Check container stats
docker stats
```
