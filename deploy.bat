@echo off
echo ==============================================
echo   DEPLOYMENT APLIKASI LAUNDRY KE VPS
echo ==============================================

echo.
echo [1/5] Melakukan Build Flutter Web...
call flutter build web --pwa-strategy=none

echo.
echo [2/5] Mengompresi hasil build...
tar -czvf web.tar.gz -C build/web .

echo.
echo [3/5] Mengunggah Frontend dan Backend ke VPS...
scp -o StrictHostKeyChecking=accept-new web.tar.gz server01@103.150.226.111:~/
scp -o StrictHostKeyChecking=accept-new server.js package.json firebase-key.json server01@103.150.226.111:~/laundry-backend/

echo.
echo [4/5] Menginstal dependensi Backend (jika ada pembaruan)...
ssh -o StrictHostKeyChecking=accept-new server01@103.150.226.111 "cd ~/laundry-backend && npm install"

echo.
echo [5/5] Memperbarui Server VPS...
ssh -o StrictHostKeyChecking=accept-new server01@103.150.226.111 "sudo tar -xzvf ~/web.tar.gz -C /var/www/html/laundry && pm2 restart laundry-backend"

echo.
echo Membersihkan file sementara...
del web.tar.gz

echo.
echo ==============================================
echo DEPLOYMENT SELESAI! APLIKASI TELAH DIPERBARUI.
echo ==============================================
