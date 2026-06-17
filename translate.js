const fs = require('fs');

function replaceInFile(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');

    // Add import if not present
    if (!content.includes('package:aplikasilaundry/localization.dart')) {
        content = content.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/material.dart';\nimport 'package:aplikasilaundry/localization.dart';"
        );
    }

    // Common replacements
    const replacements = {
        '"Welcome to Workspace!"': "AppLocalizations.tr('welcome_workspace')",
        '"Tampaknya belum ada toko yang terdaftar. Mulailah dengan menambahkan toko pertama Anda untuk mengelola mesin, token, dan memantau transaksi."': "AppLocalizations.tr('no_store_desc')",
        '"Tambah Toko Baru"': "AppLocalizations.tr('add_new_store')",
        '"Selamat Malam"': "AppLocalizations.tr('greeting_night')",
        '"Selamat Pagi"': "AppLocalizations.tr('greeting_morning')",
        '"Selamat Siang"': "AppLocalizations.tr('greeting_afternoon')",
        '"Selamat Sore"': "AppLocalizations.tr('greeting_evening')",
        '"User"': "AppLocalizations.tr('user')",
        '"Pilih Cabang"': "AppLocalizations.tr('choose_branch')",
        '"Alamat diatur oleh Admin"': "AppLocalizations.tr('branch_not_set')",
        '"Sisa Token"': "AppLocalizations.tr('token_balance')",
        '"Paket Premium"': "AppLocalizations.tr('premium_package')",
        '"Token"': "AppLocalizations.tr('token')",
        '"Berlaku sampai"': "AppLocalizations.tr('valid_until')",
        '"Berlaku selamanya"': "AppLocalizations.tr('valid_forever')",
        '"Pendapatan Hari Ini"': "AppLocalizations.tr('today_income')",
        '"Dari kemarin "': "AppLocalizations.tr('from_yesterday') + ' '",
        '"Status Mesin"': "AppLocalizations.tr('machine_status')",
        '"Lihat Semua >"': "AppLocalizations.tr('see_all')",
        '"Washer Aktif"': "AppLocalizations.tr('washer_active')",
        '"Washer Idle"': "AppLocalizations.tr('washer_idle')",
        '"Dryer Aktif"': "AppLocalizations.tr('dryer_active')",
        '"Dryer Idle"': "AppLocalizations.tr('dryer_idle')",
        '"Mesin Berjalan"': "AppLocalizations.tr('running_machines')",
        '"Transaksi (30 Hari Terakhir)"': "AppLocalizations.tr('transactions_30_days')",
        '"Aktivitas Terbaru"': "AppLocalizations.tr('recent_activities')",
        '"Belum ada aktivitas."': "AppLocalizations.tr('no_activity')",
        '"Baru saja"': "AppLocalizations.tr('just_now')",
        '"menit lalu"': "AppLocalizations.tr('mins_ago')",
        '"jam lalu"': "AppLocalizations.tr('hours_ago')",
        '"hari lalu"': "AppLocalizations.tr('days_ago')",
        '"Beranda"': "AppLocalizations.tr('home')",
        '"Mesin"': "AppLocalizations.tr('machine')",
        '"Transaksi"': "AppLocalizations.tr('transaction')",
        '"Stats"': "AppLocalizations.tr('stats')",
        '"Profil"': "AppLocalizations.tr('profile')",
        '"Buat Transaksi"': "AppLocalizations.tr('create_transaction')",
        '"Cuci Saja"': "AppLocalizations.tr('wash_only')",
        '"Kering Saja"': "AppLocalizations.tr('dry_only')",
        '"Paket Combo"': "AppLocalizations.tr('combo_package')",
        '"Pelanggan Baru"': "AppLocalizations.tr('new_customer')",
        '"Tambah ke Antrean"': "AppLocalizations.tr('add_to_queue')",
        '"Top Up Token"': "AppLocalizations.tr('top_up_token')",
        '"Tutup"': "AppLocalizations.tr('close')",
    };

    for (const [key, value] of Object.entries(replacements)) {
        // We use split and join to replace all occurrences
        content = content.split(key).join(value);
    }

    // Special fix for greeting interpolations like "👋 $greeting,"
    content = content.replace(/"👋 \$greeting,"/g, '"👋 " + greeting + ","');
    
    fs.writeFileSync(filePath, content);
}

replaceInFile('lib/home_tab.dart');
replaceInFile('lib/dashboard.dart');

console.log('Translation applied successfully.');
