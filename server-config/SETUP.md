# Server Setup Guide

Server: 103.47.224.92
SSH: `ssh -i ~/.ssh/id_rsa_noralooks root@103.47.224.92`

## Apps on this server

| App | Domain | Working Dir | Puma Service |
|-----|--------|-------------|--------------|
| test-cht (dmart) | med.qd.je | /var/www/test-cht | puma-test-cht |
| codes-pro | www.codeswords.com | /var/www/codes-pro | puma-codes-pro |
| noralooks | www.noralooks.com | /var/www/backoffice-storefront | puma-noralooks |
| staging-noralooks | staging.noralooks.com | /var/www/backoffice-storefront-staging | puma-staging |
| docsgent | docsgent.tecorb.in | /var/www/docsgent | puma-docsgent |

## Setup Steps for a New App

### 1. Copy nginx config
```bash
sudo cp server-config/nginx/sites-available/<app-name> /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/<app-name> /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 2. Copy systemd puma service
```bash
sudo cp server-config/systemd/puma-<app-name>.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable puma-<app-name>
sudo systemctl start puma-<app-name>
```

### 3. SSL with Let's Encrypt
```bash
sudo certbot --nginx -d <domain> --redirect
```

### 4. Useful commands
```bash
# Check puma status
sudo systemctl status puma-<app-name>

# Restart puma
sudo systemctl restart puma-<app-name>

# Check nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# View puma logs
sudo journalctl -u puma-<app-name> -f

# View nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

## SSL Certificates

| Domain | Cert Path | Key Path |
|--------|-----------|----------|
| med.qd.je | /root/ssl/med_qd_je.pem (self-signed, replace with certbot) | /root/ssl/med_qd_je.key |
| codeswords.com | /root/ssl/codeswords_chain.pem | /root/ssl/codeswords.key |
| noralooks.com | /root/ssl/noralooks_chain_new.pem | /root/ssl/noralooks_new.key |

## Ruby Environment
- Managed via rbenv at `/root/.rbenv/`
- Puma binds to unix sockets at `<app-dir>/tmp/sockets/puma.sock`
