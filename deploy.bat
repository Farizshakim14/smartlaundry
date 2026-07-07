@echo off
echo ==============================================
echo   DEPLOYMENT APLIKASI LAUNDRY KE VPS
echo ==============================================

echo.
echo [1/6] Melakukan Build Flutter Web...
call flutter build web --pwa-strategy=none

echo.
echo [2/6] Melakukan Build Flutter APK...
call flutter build apk --release

echo.
echo [3/6] Mengompresi hasil build web...
tar -czvf web.tar.gz -C build/web .

echo.
echo [4/6] Mengunggah Frontend, APK, dan Backend ke VPS...
scp -o StrictHostKeyChecking=accept-new web.tar.gz server01@103.150.226.111:~/
scp -o StrictHostKeyChecking=accept-new build\app\outputs\flutter-apk\app-release.apk server01@103.150.226.111:~/app-release.apk
scp -o StrictHostKeyChecking=accept-new server.js package.json firebase-key.json server01@103.150.226.111:~/laundry-backend/

echo.
echo [5/6] Menginstal dependensi Backend (jika ada pembaruan)...
ssh -o StrictHostKeyChecking=accept-new server01@103.150.226.111 "cd ~/laundry-backend && npm install"

echo.
echo [6/6] Memperbarui Server VPS...
ssh -o StrictHostKeyChecking=accept-new server01@103.150.226.111 "sudo tar -xzvf ~/web.tar.gz -C /var/www/html/laundry && sudo mv ~/app-release.apk /var/www/html/laundry/app.apk && pm2 restart laundry-backend"

echo.
echo Membersihkan file sementara...
del web.tar.gz

echo.
echo ==============================================
echo DEPLOYMENT SELESAI! APLIKASI TELAH DIPERBARUI.
echo Aplikasi Android siap diunduh di: http://103.150.226.111/app.apk
echo ==============================================
