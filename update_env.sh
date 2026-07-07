#!/bin/bash
cd ~/machine_monitoring-api
# Ensure DB_CONNECTION is mysql
sed -i 's/DB_CONNECTION=.*/DB_CONNECTION=mysql/' .env
# Remove any existing DB_ lines to avoid duplicates
sed -i '/^DB_HOST=/d' .env
sed -i '/^DB_PORT=/d' .env
sed -i '/^DB_DATABASE=/d' .env
sed -i '/^DB_USERNAME=/d' .env
sed -i '/^DB_PASSWORD=/d' .env

# Append correct DB_ lines
echo "DB_HOST=127.0.0.1" >> .env
echo "DB_PORT=3306" >> .env
echo "DB_DATABASE=machine_monitoring" >> .env
echo "DB_USERNAME=machine_user" >> .env
echo "DB_PASSWORD=machine_password" >> .env

php artisan config:clear
php artisan migrate --force
