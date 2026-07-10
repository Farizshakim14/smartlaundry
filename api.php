<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\AuthController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/login/google', [AuthController::class, 'googleLogin']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::post('/users/delete', [AuthController::class, 'deleteUser']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);

    // Machines
    Route::get('/machines', [App\Http\Controllers\MachineController::class, 'index']);
    Route::get('/machines/{id}', [App\Http\Controllers\MachineController::class, 'show']);
    Route::post('/machines', [App\Http\Controllers\MachineController::class, 'store']);
    Route::put('/machines/{id}', [App\Http\Controllers\MachineController::class, 'update']);
    Route::delete('/machines/{id}', [App\Http\Controllers\MachineController::class, 'destroy']);
    Route::post('/machines/{id}/start', [App\Http\Controllers\MachineController::class, 'start']);
    Route::post('/machines/{id}/stop', [App\Http\Controllers\MachineController::class, 'stop']);

    // Transactions
    Route::get('/transactions', [App\Http\Controllers\MachineTransactionController::class, 'index']);
    Route::post('/transactions', [App\Http\Controllers\MachineTransactionController::class, 'store']);

    // Manual Transactions
    Route::get('/manual-transactions', [App\Http\Controllers\ManualTransactionController::class, 'index']);
    Route::post('/manual-transactions', [App\Http\Controllers\ManualTransactionController::class, 'store']);
    Route::put('/manual-transactions/{id}', [App\Http\Controllers\ManualTransactionController::class, 'update']);
    Route::delete('/manual-transactions/{id}', [App\Http\Controllers\ManualTransactionController::class, 'destroy']);
});

// Route untuk ESP32 (tanpa middleware auth agar ESP32 bisa tembak langsung)
Route::get('/esp32/commands', [App\Http\Controllers\Esp32Controller::class, 'getCommands']);
Route::post('/esp32/command/ack', [App\Http\Controllers\Esp32Controller::class, 'ackCommand']);
Route::post('/esp32/data', [App\Http\Controllers\Esp32Controller::class, 'receiveData']);
Route::post('/esp32/calibrate', [App\Http\Controllers\Esp32Controller::class, 'calibrate']);

// Midtrans Webhook
Route::post('/midtrans-webhook', [App\Http\Controllers\MidtransController::class, 'webhook']);
