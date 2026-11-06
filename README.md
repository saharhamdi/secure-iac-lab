# 🔐 secure-iac-lab

**Infrastructure as Code sécurisée : Terraform & Docker, avant / après correction, avec contrôles automatiques**
*Secure Infrastructure as Code: Terraform & Docker, before / after remediation, with automated checks*

![IaC Security Scan](../../actions/workflows/iac-security.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue)


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

*Measured with Checkov 3.3.30; numbers may change with tool versions.*

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



## About

Project built by **Sahar Hamdi**, Cybersecurity Engineer / CISO,
specialized in GRC, compliance auditing (ISO 27001, NIS2), and IAM/PAM.

- LinkedIn: [*(link to be added)*](https://www.linkedin.com/in/sahar-hamdi-989775153/)

MIT — voir / see [LICENSE](LICENSE).
