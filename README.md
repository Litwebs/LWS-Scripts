# 🚀 Deployment Prerequisites & Steps

Follow these steps to deploy the project on a fresh Ubuntu server.

---

# ✅ 1. Domain Setup (REQUIRED)

Before running any scripts, configure DNS:

1. Go to your domain provider (Namecheap, IONOS, GoDaddy, Cloudflare, etc.)
2. Add an **A Record**:

Type: A
Host: api (or whatever subdomain you want)
Value: <YOUR_SERVER_PUBLIC_IP>
TTL: Auto

Example:
api.litwebs.co.uk → 203.0.113.55

Wait 5–30 minutes for DNS to propagate.

---

./setup.sh https://github.com/Litwebs/T3Server-ABORTED.git api.litwebs.co.uk 5001 "https://litwebs.co.uk"

# ✅ 2. Create Environment Variables (REQUIRED)

SSH into your server and create the folder:

sudo nano /etc/lws-env/<api.domain.com>.env

Add all backend environment variables, for example:

MONGO_URI=mongodb://user:pass@localhost:27017/app?authSource=admin
JWT_SECRET=yourjwtsecret
STRIPE_SECRET=sk_xxxxxx
PORT=5001
NODE_ENV=production

⚠️ Do NOT put MONGO_URI, NODE_ENV, or PORT in this file.
Those are generated automatically by the deployment scripts.

Set secure permissions:

sudo chmod 600 /etc/lws-env/\*.env

---

# ✅ 3. Upload the Deployment Scripts

Clone or upload the deployment scripts to your server:

git clone https://github.com/YourUser/LWS-Scripts.git

cd LWS-Scripts

git clone https://github.com/YourUser/LWS-Scripts.git

cd LWS-Scripts

chmod +x \*.sh

---

# ✅ 4. Run the Full Deployment

Use ONE command to deploy everything:

sudo ./setup.sh <GitRepoURL> <Domain> <Port> "<AllowedOrigins>"

### Example:

sudo ./setup.sh
https://github.com/YourUser/YourRepo.git

api.litwebs.co.uk
5001
https://litwebs.co.uk
https://admin.litwebs.co.uk

This will automatically:

- Install Node 18 LTS
- Install MongoDB
- Inject your `.env` into the backend
- Install backend dependencies
- Install frontend dependencies
- Start backend via PM2
- Install Nginx + SSL
- Generate secure Nginx reverse proxy config

---

# ✅ 5. Verify Deployment

Check PM2:

pm2 status
pm2 logs express-app

Check Nginx:

sudo systemctl status nginx

Your API should now be live at:
https://api.litwebs.co.uk

---

# 🎉 Done!

Your application is fully deployed with SSL, PM2, MongoDB, and Nginx.
