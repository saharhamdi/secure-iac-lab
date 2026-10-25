# Constats ↔ contrôles ↔ référentiels

*Findings ↔ checks ↔ frameworks (FR / EN)*

Références : **ISO/IEC 27002:2022** (contrôles de l'annexe A de l'ISO 27001:2022) et **NIST CSF 2.0**.
Les identifiants de contrôle sont ceux de **Checkov** ; ils peuvent évoluer selon les versions de l'outil.

## Terraform (AWS)

| # | Constat (before) | Contrôles Checkov | Correction (after) | ISO 27002:2022 | NIST CSF 2.0 |
|---|---|---|---|---|---|
| T1 | Bucket S3 avec ACL `public-read`, sans blocage d'accès public | CKV_AWS_20, CKV2_AWS_6 | `aws_s3_bucket_public_access_block` (4 options à `true`), suppression de l'ACL | 5.15 Contrôle d'accès, 8.3 Restriction d'accès à l'information | PR.AA, PR.DS |
| T2 | Bucket non chiffré | CKV_AWS_145 | Chiffrement SSE-KMS avec clé gérée (rotation activée) | 8.24 Utilisation de la cryptographie | PR.DS-01 |
| T3 | Pas de versioning, de journalisation ni de cycle de vie | CKV_AWS_21, CKV_AWS_18, CKV2_AWS_61 | Versioning, `aws_s3_bucket_logging` vers un bucket de logs, règles de cycle de vie | 8.13 Sauvegarde, 8.15 Journalisation | PR.DS-11, DE.CM |
| T4 | Security group ouvert à `0.0.0.0/0` sur tous les ports, sans description | CKV_AWS_24, CKV_AWS_25, CKV_AWS_260, CKV_AWS_382, CKV_AWS_23 | HTTPS (443) depuis un CIDR autorisé uniquement (validation Terraform interdisant `0.0.0.0/0`), egress limité à 443, descriptions | 8.20 Sécurité des réseaux, 8.22 Cloisonnement | PR.IR-01 |
| T5 | EC2 avec IMDSv1 | CKV_AWS_79 | `http_tokens = "required"` (IMDSv2), hop limit à 1 | 8.9 Gestion de la configuration | PR.PS-01 |
| T6 | Disque racine non chiffré | CKV_AWS_8 | `encrypted = true` avec clé KMS | 8.24 Utilisation de la cryptographie | PR.DS-01 |
| T7 | IP publique, pas de monitoring, pas de rôle IAM, pas EBS-optimized | CKV_AWS_88, CKV_AWS_126, CKV2_AWS_41, CKV_AWS_135 | Sous-réseau privé, `monitoring = true`, profil d'instance IAM, `ebs_optimized = true` | 8.16 Activités de surveillance, 8.20 Sécurité des réseaux | DE.CM, PR.IR |
| T8 | Politique IAM `Action:* / Resource:*` | CKV_AWS_62, 63, 355, 286 à 290, CKV2_AWS_40 | Politique de moindre privilège (lecture du bucket + `kms:Decrypt`) | 5.15 Contrôle d'accès, 8.2 Droits d'accès privilégiés | PR.AA-05 |

### Exceptions documentées (Terraform after)

| Contrôle | Ressource | Justification |
|---|---|---|
| CKV_AWS_144 | `logs`, `data` | Réplication inter-région hors périmètre du lab (coût, complexité) |
| CKV2_AWS_62 | `logs`, `data` | Notifications d'événements S3 non nécessaires au besoin fonctionnel |
| CKV_AWS_18 | `logs` | Bucket de journalisation : pas de journalisation en cascade |

Ces exceptions sont déclarées par des commentaires `checkov:skip` dans `terraform/after/main.tf`. En production, chacune doit être validée et tracée (analyse de risque, date de revue).

## Docker

| # | Constat (before) | Contrôle | Correction (after) | ISO 27002:2022 | NIST CSF 2.0 |
|---|---|---|---|---|---|
| D1 | Image de base `python:latest` | CKV_DOCKER_7 | Version épinglée `python:3.12.7-slim-bookworm` | 8.8 Gestion des vulnérabilités techniques, 8.9 | PR.PS-02 |
| D2 | Exécution en root | CKV_DOCKER_3 | Utilisateur dédié (UID 10001) + `USER 10001` | 8.2 Droits d'accès privilégiés | PR.AA-05 |
| D3 | Secrets dans l'image (`ENV`) et dans le compose | (Gitleaks / Trivy) | Secret Docker monté dans `/run/secrets`, lecture via `SECRET_KEY_FILE` | 8.24, 5.17 Informations d'authentification | PR.AA-01, PR.DS-01 |
| D4 | `ADD . /app` | CKV_DOCKER_4 | `COPY` ciblé + `.dockerignore` | 8.9 Gestion de la configuration | PR.PS-01 |
| D5 | Pas de `HEALTHCHECK` | CKV_DOCKER_2 | `HEALTHCHECK` sur `/health` | 8.16 Activités de surveillance | DE.CM-09 |
| D6 | Port 22 exposé | CKV_DOCKER_1 | Seul le port 5000 est exposé, publié sur `127.0.0.1` | 8.20 Sécurité des réseaux | PR.IR-01 |
| D7 | `privileged: true` | (Trivy / revue) | Suppression, `cap_drop: ALL`, `no-new-privileges`, `read_only` | 8.2, 8.9 | PR.PS-01 |
| D8 | Montage de `/var/run/docker.sock` | (Trivy / revue) | Supprimé (accès équivalent à root sur l'hôte) | 8.2, 8.3 | PR.AA-05 |
| D9 | Mode debug Flask actif | (revue de code) | `debug=False` | 8.9, 8.28 Codage sécurisé | PR.PS-06 |
| D10 | Pas de limites de ressources | (Trivy / revue) | `cpus`, `memory`, `pids_limit` | 8.6 Dimensionnement | PR.IR-04 |

## Notes

- Les correspondances ISO / NIST sont **indicatives** : un même constat peut relever de plusieurs contrôles.
- Les contrôles marqués « (revue) » ne sont pas tous détectés par Checkov sur les fichiers Docker Compose ; ils sont couverts par Trivy (configuration) ou par revue.
- English summary: each finding lists the Checkov check IDs, the remediation applied in the `after` folders, and an indicative mapping to ISO/IEC 27002:2022 and NIST CSF 2.0. Mappings are indicative; documented exceptions are `checkov:skip` comments in `terraform/after/main.tf`.
