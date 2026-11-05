# OVHcloud Public Cloud: Load Balancer → Web Server → SQL Server 2025 (Terraform)

Deploys a small, fully automated three-tier setup on **OVHcloud Public Cloud** with Terraform:

- a **load balancer** (OVHcloud Octavia) with a public IP,
- a **web server** (Ubuntu 24.04, nginx + Node.js) serving a "Hello World" page,
- a **database server** (b3-8, Ubuntu 24.04) running **Microsoft SQL Server 2025**,
- a **private network** connecting everything, with firewall rules so the database is only reachable from the web server.

Everything is 100 % Infrastructure as Code: no manual steps and no pre-built images. SQL Server is installed and configured with cloud-init on first boot.

```
Internet ──► Floating IP ──► Load Balancer (HTTP :80)
                                   │
                        private network 10.0.0.0/24
                                   │
                      hello-web  10.0.0.10   nginx + Node.js
                                   │  TCP 1433
                      hello-db   10.0.0.20   SQL Server 2025
```

After deployment:

- `http://<lb-ip>/` shows a static Hello World page.
- `http://<lb-ip>/db` queries SQL Server and shows a message from the database plus `@@VERSION`.

---

## Table of contents

1. [Repository layout](#repository-layout)
2. [Prerequisites](#prerequisites)
3. [Setup on OVHcloud](#setup-on-ovhcloud)
4. [Configuration](#configuration)
5. [Deploying](#deploying)
6. [What happens on first boot](#what-happens-on-first-boot)
7. [Accessing the servers (SSH)](#accessing-the-servers-ssh)
8. [Troubleshooting](#troubleshooting)
9. [Destroying everything](#destroying-everything)
10. [Security notes](#security-notes)
11. [Costs and licensing](#costs-and-licensing)

---

## Repository layout

| File | Purpose |
|---|---|
| `provider.tf` | Terraform backend (S3 state in OVHcloud Object Storage), provider versions, OVH and OpenStack provider config |
| `variables.tf` | All input variables (credentials, region, flavors, passwords, IPs) |
| `network.tf` | Private network, subnet, router with internet access |
| `security.tf` | Security groups: HTTP only from the private subnet (load balancer), MSSQL only from the web server, optional SSH |
| `instance.tf` | SSH key pair, database instance, web server instance, optional public IP for SSH |
| `loadbalancer.tf` | Load balancer, HTTP listener, pool, health monitor, member, public IP |
| `output.tf` | Website URL, DB test URL, SSH commands |
| `scripts/db-init.sh.tftpl` | cloud-init script: installs SQL Server 2025, creates `HelloDB`, table `Greetings` and login `webapp` |
| `scripts/web-init.sh.tftpl` | cloud-init script: installs nginx, Node.js, the Hello World page and a small Node app for `/db` |

---

## Prerequisites

- An **OVHcloud Public Cloud project**.
- **Terraform ≥ 1.6**.
- Optional: the **OpenStack CLI** (`pip install python-openstackclient`) for troubleshooting.

---

## Setup on OVHcloud

### 1. OpenStack user (required)

Terraform creates all resources through the OpenStack API.

1. In the OVHcloud Control Panel go to **Public Cloud → your project → Project Management → Users & Roles**.
2. Create a user with the **Administrator** role (or at least *Compute Operator*, *Network Operator* and *Load Balancer Operator*).
3. Note the **username** and **password**.
4. Note your **project ID** (shown at the top of the project, 32 hex characters). It is used as `ovh_service_name` / `tenant_id`.

### 2. OVH API credentials (required by the current config)

The `ovh` provider is configured in `provider.tf`, so it needs credentials even though no `ovh_*` resources are used yet.

Create an application key, application secret and consumer key at <https://eu.api.ovh.com/createToken/> (EU endpoint, matching `endpoint = "ovh-eu"`).

> If you do not plan to use OVH API resources, you can remove the `ovh` provider block, its entry in `required_providers` and the three `ovh_*` variables.

### 3. Object Storage bucket for Terraform state (required)

The state is stored remotely, so plans and applies from CI and different machines share it.

1. Go to **Public Cloud → Object Storage** and create an **S3-compatible** bucket in the same location as configured in `provider.tf` (e.g. `DE`).
2. Create an **S3 user** (Object Storage users) and note its **access key** and **secret key**.
3. Put the bucket name into `provider.tf`:

```hcl
backend "s3" {
  bucket = "your-bucket-name"
  key    = "terraform.tfstate"
  region = "de"
  endpoints = {
    s3 = "https://s3.de.io.cloud.ovh.net"
  }
  ...
}
```

> Terraform does not allow variables in the `backend` block. Either hard-code the bucket name or leave the `bucket` line out and pass it at init time:
> `terraform init -backend-config="bucket=your-bucket-name"`

### 4. SSH key pair (required)

The VMs only allow key-based SSH login. You need the **public** key of the machine you will log in from:

```bash
cat ~/.ssh/id_ed25519.pub        # or create one: ssh-keygen -t ed25519
```

Only the `.pub` file is used. Never commit or upload the private key.

---

## Configuration

### Required variables

| Variable | Description |
|---|---|
| `ovh_service_name` | Public Cloud project ID |
| `ovh_application_key` | OVH API application key |
| `ovh_application_secret` | OVH API application secret |
| `ovh_consumer_key` | OVH API consumer key |
| `openstack_user` | OpenStack username |
| `openstack_password` | OpenStack password |
| `ssh_public_key` | Contents of your public SSH key (`ssh-ed25519 AAAA...`) |
| `sa_password` | SQL Server `sa` password |
| `app_db_password` | Password for the SQL login `webapp` used by the web server |

**Password rules:** at least 8 characters, with upper case, lower case, a digit and a special character (SQL Server policy). The characters `'` `"` `\` `$` `` ` `` are not allowed, because they would break the shell scripts.

### Optional variables (defaults)

| Variable | Default | Description |
|---|---|---|
| `prefix` | `hello` | Prefix for all resource names |
| `db_image_name` | `Ubuntu 24.04` | Base image for the DB server |
| `web_image_name` | `Ubuntu 24.04` | Base image for the web server |
| `db_flavor` | `b3-8` | Instance flavor for the database |
| `web_flavor` | `d2-4` | Instance flavor for the web server |
| `mssql_pid` | `Express` | SQL Server 2025 edition: `Express`, `StandardDeveloper`, `EnterpriseDeveloper`, `Standard`, `Enterprise`, `Evaluation` or a product key |
| `enable_ssh` | `false` | `true` attaches a public IP to the web server for SSH |
| `ssh_allowed_cidr` | `0.0.0.0/0` | Source range allowed to SSH into the web server (use `your.ip/32`) |
| `subnet_cidr` | `10.0.0.0/24` | Private subnet |
| `web_ip` | `10.0.0.10` | Fixed private IP of the web server |
| `db_ip` | `10.0.0.20` | Fixed private IP of the database |

### Region

The region is set in the `openstack` provider in `provider.tf` (currently `DE1`). Image names can differ between regions. Check them with:

```bash
openstack --os-region-name DE1 image list --public | grep -i "24.04"
```

---

## Deploying

Terraform reads every environment variable named `TF_VAR_<name>` as the value of variable `<name>`. The S3 backend reads the state credentials from `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`.

```bash
# Terraform state credentials
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# Terraform variables
export TF_VAR_ovh_service_name=...
export TF_VAR_ovh_application_key=...
export TF_VAR_ovh_application_secret=...
export TF_VAR_ovh_consumer_key=...
export TF_VAR_openstack_user=...
export TF_VAR_openstack_password=...
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
export TF_VAR_sa_password='...'
export TF_VAR_app_db_password='...'

terraform init
terraform plan
terraform apply
terraform output
```

Alternatively, put the variables into a `terraform.tfvars` file in the project folder, which Terraform loads automatically. **Never commit it** (see `.gitignore` below).

```hcl
ovh_service_name       = "..."
ovh_application_key    = "..."
ovh_application_secret = "..."
ovh_consumer_key       = "..."
openstack_user         = "..."
openstack_password     = "..."
ssh_public_key         = "ssh-ed25519 AAAA... you@host"
sa_password            = "..."
app_db_password        = "..."
```

> **Running it in CI (e.g. GitHub Actions, GitLab CI):** store the values as CI secrets, expose them to the job as the `TF_VAR_*` and `AWS_*` environment variables shown above, and run `terraform init` and `terraform apply -auto-approve`. Because the state is stored in Object Storage, local runs and CI runs share the same state.

---

## What happens on first boot

Terraform finishes after a few minutes, but the servers still need time to install software.

| Server | Script | Duration |
|---|---|---|
| Web | `scripts/web-init.sh.tftpl` | approx. 3–5 min |
| DB | `scripts/db-init.sh.tftpl` | approx. 5–8 min |

**Database (`db-init.sh.tftpl`):**
1. Adds the Microsoft package repositories for Ubuntu 24.04 and SQL Server 2025.
2. Installs `mssql-server`, `mssql-tools18` and `msodbcsql18`.
3. Runs `mssql-conf setup` with the edition from `mssql_pid` and the `sa` password (accepting the EULA).
4. Creates database `HelloDB`, table `dbo.Greetings` with one row, and login/user `webapp` with read-only access (`db_datareader`).

**Web server (`web-init.sh.tftpl`):**
1. Installs nginx, Node.js and npm.
2. Writes the static Hello World page to `/var/www/html/index.html`.
3. Installs a small Express app (`/opt/helloapp`) as the systemd service `helloapp` on `127.0.0.1:3000`. It connects to SQL Server with the `webapp` login.
4. Configures nginx to serve `/` statically and proxy `/db` to the Node app.

Until the database is ready, `/db` returns a database error. `/` works as soon as the web server is ready.

> Any change to these scripts changes the instance `user_data`, and Terraform will **recreate** the affected VM on the next apply.

---

## Accessing the servers (SSH)

By default no server has a public IP apart from the load balancer. To enable SSH, set:

```bash
export TF_VAR_enable_ssh=true
export TF_VAR_ssh_allowed_cidr="your.public.ip/32"
terraform apply
```

After `apply`, `terraform output` shows the commands:

```bash
ssh ubuntu@<web-public-ip>                              # web server
ssh -J ubuntu@<web-public-ip> ubuntu@10.0.0.20          # database, via the web server as jump host
```

Logs on the servers:

```bash
sudo cat /var/log/web-init.log
sudo cat /var/log/db-init.log
```

---

## Troubleshooting

All commands below need the OpenStack CLI with your credentials (OpenRC file from **Users & Roles → Download OpenStack's RC file**).

**Website returns 503**

The load balancer has no healthy backend. Usually the web server is still installing. Wait 5 minutes, then check:

```bash
openstack loadbalancer member list hello-pool -c address -c operating_status
```

`ONLINE` means healthy. If it shows `ERROR`, check the boot log.

**Check the boot log without SSH**

Both scripts also write to the instance console:

```bash
openstack --os-region-name DE1 console log show hello-web | tail -n 40
openstack --os-region-name DE1 console log show hello-db  | tail -n 40
```

**`/db` shows a database error**

- The database may still be installing. Wait until `DB-Init fertig.` appears in the DB console log.
- Login failed: `app_db_password` probably changed after the DB was created. Recreate the DB instance (`terraform apply -replace=openstack_compute_instance_v2.db`).

**`Your query returned no results` for an image**

The image name does not exist in this region. List the images (see [Region](#region)) and adjust `db_image_name` / `web_image_name`.

**`No value for required variable`**

A required variable is missing or empty. Check that the `TF_VAR_*` environment variable is exported in the same shell (or that the value is in `terraform.tfvars`) and that the name matches exactly.

**`Variables may not be used here` in `provider.tf`**

Variables are not allowed in the `backend` block. See [Object Storage bucket](#3-object-storage-bucket-for-terraform-state-required).

---

## Destroying everything

All resources (instances, load balancer, floating IPs, network) are billed while they exist.

With the same environment variables as for deploying:

```bash
terraform destroy
```

The state bucket and the OVH users are not managed by Terraform and must be deleted manually if no longer needed.

---

## Security notes

This project is a demo and learning setup. Before using it for anything real, consider the following:

- **Secrets in Terraform state and instance metadata:** the passwords are rendered into the cloud-init `user_data` and stored in the Terraform state. Keep the state bucket private and restrict its S3 credentials.
- **TLS:** the web app connects to SQL Server with `trustServerCertificate: true` (self-signed certificate). The site is served over plain HTTP. Add an HTTPS listener with a certificate for production use.
- **`webapp` login** is created with `CHECK_POLICY = OFF` and read-only permissions.
- **Network:** port 1433 is only open for the web server's private IP. SSH to the DB is only possible from the private subnet. Restrict `ssh_allowed_cidr` when `enable_ssh` is on.
- **Never commit** `terraform.tfvars`, state files or private keys. Recommended `.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
tfplan
terraform.log
crash.log
```

---

## Costs and licensing

- OVHcloud bills the instances (`b3-8`, `d2-4`), the load balancer, floating IPs, Object Storage and outgoing traffic. See the OVHcloud Public Cloud price list for current prices.
- **SQL Server:** the setup script accepts the Microsoft SQL Server EULA on your behalf. By deploying it, you agree to the Microsoft license terms for the chosen edition.
  - `Express` is free and may be used in production, with resource limits.
  - `StandardDeveloper` / `EnterpriseDeveloper` are free for development and testing only.
  - `Standard` / `Enterprise` require a license.

---

## References

- [Install SQL Server on Ubuntu (Microsoft Learn)](https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu)
- [OpenStack Terraform provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs)
- [OVHcloud Terraform provider](https://registry.terraform.io/providers/ovh/ovh/latest/docs)
- [OVHcloud Public Cloud documentation](https://help.ovhcloud.com/csm/en-public-cloud-compute-getting-started)
