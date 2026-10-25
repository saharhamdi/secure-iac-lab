# 🔐 secure-iac-lab

**Infrastructure as Code sécurisée : Terraform & Docker, avant / après correction, avec contrôles automatiques**
*Secure Infrastructure as Code: Terraform & Docker, before / after remediation, with automated checks*

![IaC Security Scan](../../actions/workflows/iac-security.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue)

[🇫🇷 Français](#-français) · [🇬🇧 English](#-english)

---

## 🇫🇷 Français

### Objectif

Montrer, sur des exemples concrets, comment on **détecte** puis **corrige** les erreurs de configuration les plus courantes dans le code d'infrastructure, et comment on **empêche leur retour** grâce à un pipeline automatisé (approche DevSecOps / *shift-left*).

Chaque cas existe en deux versions :

| Dossier | Contenu |
|---|---|
| `terraform/before` · `docker/before` | Code **volontairement vulnérable** (à ne jamais déployer) |
| `terraform/after` · `docker/after` | Même besoin fonctionnel, **durci** et conforme aux contrôles |

### Résultats

| Cible | Version | Contrôles réussis | Contrôles en échec |
|---|---|---|---|
| Terraform (AWS) | avant | 7 | **28** |
| Terraform (AWS) | après | 65 | **0** (5 exceptions documentées) |
| Dockerfile | avant | 31 | **5** |
| Dockerfile | après | 48 | **0** |

*Mesuré avec Checkov 3.3.29. Les chiffres peuvent évoluer avec les versions de l'outil.*

Les 5 exceptions Terraform sont déclarées dans `terraform/after/main.tf` (commentaires `checkov:skip` avec justification) : réplication inter-région et notifications d'événements S3 (hors périmètre du lab), et journalisation du bucket de logs lui-même.

### Ce qui est couvert

**Terraform (AWS)** : bucket S3 public / non chiffré, security group ouvert à Internet, EC2 avec IMDSv1 et disque non chiffré, politique IAM `*:*`.

**Docker** : image `latest`, exécution en root, secrets dans l'image, `ADD`, absence de `HEALTHCHECK`, `privileged`, montage de `docker.sock`, mode debug, ports exposés, absence de limites de ressources.

Le détail de chaque constat (contrôle, correction, lien avec ISO 27002:2022 et NIST CSF 2.0) est dans [`docs/findings-mapping.md`](docs/findings-mapping.md).

### Structure

```
secure-iac-lab/
├── terraform/
│   ├── before/main.tf          # vulnérable
│   └── after/                  # durci (main.tf, variables.tf)
├── docker/
│   ├── before/                 # Dockerfile, app.py, docker-compose.yml vulnérables
│   └── after/                  # versions durcies + .dockerignore
├── docs/findings-mapping.md    # constats ↔ contrôles ↔ référentiels
├── scripts/run-local.sh        # contrôles en local
└── .github/workflows/iac-security.yml
```

### Utilisation en local

```bash
pip install checkov
bash scripts/run-local.sh
```

Ou manuellement :

```bash
checkov -d terraform/before --framework terraform   # échecs attendus
checkov -d terraform/after  --framework terraform   # doit réussir
checkov -d docker/after     --framework dockerfile
```

Pour Docker Compose, lancez `docker compose up` depuis `docker/after` après avoir créé le fichier `secret_key.txt` (non versionné) :

```bash
cd docker/after
python3 -c "import secrets; print(secrets.token_urlsafe(48))" > secret_key.txt
docker compose up --build
```

### Pipeline CI (GitHub Actions)

Le workflow `.github/workflows/iac-security.yml` exécute :

- **Checkov** (Terraform et Dockerfile), **Hadolint** et **Trivy** (configuration) sur les versions `after` : le pipeline doit être **vert** ;
- **Checkov** et **Gitleaks** sur les versions `before` : rapports publiés en artefacts, sans bloquer le pipeline, pour comparer.

Les résultats SARIF sont envoyés vers l'onglet *Security* du dépôt (dépôt public, ou dépôt privé avec GitHub Advanced Security).

### Pistes d'amélioration

- Épingler les actions GitHub par SHA de commit.
- Ajouter un scan des dépendances (Trivy / OSV-Scanner) et un SBOM (Syft).
- Ajouter des politiques sur mesure (Checkov custom policies ou OPA/Conftest).
- Ajouter une version Kubernetes (manifests ou Helm) avant / après.

### Avertissement

Le code `before` est un support pédagogique. Les valeurs (noms de buckets, AMI, identifiants) sont fictives. Aucune donnée réelle d'organisation n'est utilisée.

---

## 🇬🇧 English

### Goal

Show, with concrete examples, how to **detect** and **fix** the most common misconfigurations in infrastructure code, and how to **prevent them from coming back** with an automated pipeline (DevSecOps / *shift-left*).

Each case exists in two versions:

| Folder | Content |
|---|---|
| `terraform/before` · `docker/before` | **Intentionally vulnerable** code (never deploy) |
| `terraform/after` · `docker/after` | Same functional need, **hardened** and passing the checks |

### Results

| Target | Version | Passed | Failed |
|---|---|---|---|
| Terraform (AWS) | before | 7 | **28** |
| Terraform (AWS) | after | 65 | **0** (5 documented exceptions) |
| Dockerfile | before | 31 | **5** |
| Dockerfile | after | 48 | **0** |

*Measured with Checkov 3.3.29; numbers may change with tool versions.*

The 5 Terraform exceptions are declared in `terraform/after/main.tf` (`checkov:skip` comments with a justification): cross-region replication and S3 event notifications (out of scope for the lab), and access logging on the log bucket itself.

### What is covered

**Terraform (AWS):** public / unencrypted S3 bucket, security group open to the Internet, EC2 with IMDSv1 and unencrypted disk, `*:*` IAM policy.

**Docker:** `latest` image, running as root, secrets baked into the image, `ADD`, no `HEALTHCHECK`, `privileged`, `docker.sock` mount, debug mode, exposed ports, no resource limits.

Each finding (check, fix, mapping to ISO 27002:2022 and NIST CSF 2.0) is detailed in [`docs/findings-mapping.md`](docs/findings-mapping.md).

### Run locally

```bash
pip install checkov
bash scripts/run-local.sh
```

Or manually:

```bash
checkov -d terraform/before --framework terraform   # failures expected
checkov -d terraform/after  --framework terraform   # must pass
checkov -d docker/after     --framework dockerfile
```

To run the hardened container, create an untracked `secret_key.txt` first:

```bash
cd docker/after
python3 -c "import secrets; print(secrets.token_urlsafe(48))" > secret_key.txt
docker compose up --build
```

### CI pipeline (GitHub Actions)

The workflow `.github/workflows/iac-security.yml` runs:

- **Checkov** (Terraform and Dockerfile), **Hadolint** and **Trivy** (config) on the `after` folders: the pipeline must be **green**;
- **Checkov** and **Gitleaks** on the `before` folders: reports published as artifacts, non-blocking, for comparison.

SARIF results are uploaded to the repository's *Security* tab (public repository, or private with GitHub Advanced Security).

### Ideas for improvement

- Pin GitHub Actions to commit SHAs.
- Add dependency scanning (Trivy / OSV-Scanner) and an SBOM (Syft).
- Add custom policies (Checkov custom policies or OPA/Conftest).
- Add a Kubernetes (manifests or Helm) before / after example.

### Disclaimer

The `before` code is a teaching sample. All values (bucket names, AMI, credentials) are fictitious. No real organisation data is used.

---

## 📄 Licence / License

MIT — voir / see [LICENSE](LICENSE).
