# Rails Application

A Ruby on Rails e-commerce application using PostgreSQL, deployed on **AWS EC2 (Ubuntu 24.04 LTS)** with **Nginx + Phusion Passenger**.

---

## Project Overview

- **Ruby Version**: 3.1.2
- **Rails Version**: 7.1.3.4
- **Database**: PostgreSQL
- **Web Server**:
  - Development: Puma
  - Production: Nginx + Phusion Passenger
- **OS (Production)**: Ubuntu 24.04 LTS (AWS EC2)

### Key Features
- Product catalog with pagination
- Real-time notifications (Pusher)
- Image uploads (Cloudinary)
- Soft deletes (Paranoia gem)

---

## AWS EC2 Deployment Guide (Ubuntu 24.04 LTS)

This guide is **validated for Ubuntu 24.04 LTS** running on AWS EC2 with the AWS kernel.

### Prerequisites

- AWS EC2 instance running **Ubuntu 24.04 LTS**
- SSH access (key-based)
- Optional: Domain pointing to EC2 public IP

---

## Step 1: Connect to EC2 & Update System

```bash
ssh -i your-key.pem ubuntu@your-ec2-ip

sudo apt update && sudo apt upgrade -y
```

---

## Step 2: Install System Dependencies

```bash
sudo apt install -y \
  curl gnupg2 ca-certificates dirmngr \
  git build-essential \
  libssl-dev libreadline-dev zlib1g-dev \
  libyaml-dev libgmp-dev libffi-dev \
  libpq-dev
```

---

## Step 3: Install RVM & Ruby 3.1.2

Phusion Passenger works best with **RVM-managed Ruby**.

```bash
gpg --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 \
               7D2BAF1CF37B13E2069D6956105BD0E739499BDB

curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm

rvm install 3.1.2
rvm use 3.1.2 --default

gem install bundler -v 2.5.3
```

Verify:
```bash
ruby -v   # ruby 3.1.2
bundle -v # bundler 2.5.3
```

---

## Step 4: Install PostgreSQL

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

### Create Database & User

```bash
sudo -u postgres psql <<EOF
CREATE USER dmart WITH PASSWORD 'your_secure_password';
CREATE DATABASE dmart_production OWNER dmart;
ALTER USER dmart CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE dmart_production TO dmart;
EOF
```

---

## Step 5: Install Nginx & Phusion Passenger

Ubuntu 24.04 provides Passenger directly via APT.

```bash
sudo apt install -y nginx libnginx-mod-http-passenger
sudo systemctl enable nginx
sudo systemctl restart nginx
```

Verify Passenger:
```bash
sudo passenger-config validate-install
sudo passenger-status
```

---

## Step 6: Clone & Configure Application

```bash
sudo mkdir -p /var/www/dmart
sudo chown ubuntu:ubuntu /var/www/dmart

cd /var/www/dmart
git clone https://github.com/your-username/dmart.git .
```

Install gems in production mode:

```bash
bundle config set deployment true
bundle config set without 'development test'
bundle install
```

---

## Step 7: Environment Variables

Create `.env` file:

```bash
nano /var/www/dmart/.env
```

```env
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true

DATABASE_URL=postgresql://dmart:your_secure_password@localhost/dmart_production
DMART_DATABASE_PASSWORD=your_secure_password

RAILS_MASTER_KEY=your_master_key
SECRET_KEY_BASE=your_secret_key_base

CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

PUSHER_APP_ID=your_pusher_app_id
PUSHER_KEY=your_pusher_key
PUSHER_SECRET=your_pusher_secret
PUSHER_CLUSTER=your_pusher_cluster
```

Secure it:
```bash
chmod 600 .env
```

---

## Step 8: Database & Assets

```bash
bundle exec rails db:migrate
bundle exec rails assets:precompile
```

---

## Step 9: Nginx Passenger Configuration

```bash
sudo nano /etc/nginx/sites-available/dmart
```

```nginx
server {
  listen 80;
  server_name your-domain.com your-ec2-ip;

  root /var/www/dmart/public;

  passenger_enabled on;
  passenger_app_env production;
  passenger_ruby /home/ubuntu/.rvm/gems/ruby-3.1.2/wrappers/ruby;

  client_max_body_size 4M;

  add_header X-Frame-Options SAMEORIGIN;
  add_header X-Content-Type-Options nosniff;

  location ~ ^/(assets|packs) {
    expires max;
    gzip_static on;
  }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/dmart /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## Step 10: SSL (Recommended)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## Step 11: Permissions & Restart

```bash
mkdir -p tmp log
touch tmp/restart.txt
chmod -R 755 /var/www/dmart
```

---

## Deploy Updates

```bash
cd /var/www/dmart
git pull origin main
bundle install
bundle exec rails db:migrate
bundle exec rails assets:precompile
touch tmp/restart.txt
```

---

## Monitoring & Troubleshooting

```bash
sudo systemctl status nginx
sudo systemctl status postgresql
sudo passenger-status

tail -f log/production.log
tail -f /var/log/nginx/error.log
```

---

## Notes for Ubuntu 24.04

- Passenger is installed directly via APT (no external repo needed)
- OpenSSL 3 is default (Ruby 3.1.2 via RVM is compatible)
- systemd manages all services
- AWS kernel does not expose temperature sensors (normal behavior)

---

## License

MIT

