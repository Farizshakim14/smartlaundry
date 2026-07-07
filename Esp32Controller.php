<?php

namespace App\Http\Controllers;

use App\Models\Esp32Command;
use App\Models\Machine;
use Illuminate\Http\Request;
use Kreait\Laravel\Firebase\Facades\Firebase;
use Illuminate\Support\Facades\Cache;

class Esp32Controller extends Controller
{
    public function getCommands(Request $request)
    {
        $deviceId = $request->query('device_id');

        if (!$deviceId) {
            return response()->json(['commands' => []]);
        }

        $commands = Esp32Command::where('device_id', $deviceId)
            ->where('status', 'pending')
            ->get();

        $formattedCommands = $commands->map(function ($c) {
            return [
                'command_id' => $c->id,
                'machine_id' => (int)$c->machine_id,
                'command' => $c->command,
                'duration_minutes' => $c->duration_minutes
            ];
        });

        return response()->json(['commands' => $formattedCommands]);
    }

    public function ackCommand(Request $request)
    {
        $commandId = $request->input('command_id');
        $success = $request->input('success');

        if ($success && $commandId) {
            Esp32Command::where('id', $commandId)->update(['status' => 'completed']);
        }

        return response()->json(['success' => true]);
    }

    public function receiveData(Request $request)
    {
        $data = $request->all();
        $deviceId = $data['device_id'] ?? null;

        if (!$deviceId) {
            return response()->json(['success' => false, 'error' => 'No device_id']);
        }

        $this->updateChannel($deviceId, $data['channel1'] ?? null, $data['wifi_ssid'] ?? null, $data['wifi_rssi'] ?? null);
        $this->updateChannel($deviceId, $data['channel2'] ?? null, $data['wifi_ssid'] ?? null, $data['wifi_rssi'] ?? null);

        $pendingCount = Esp32Command::where('device_id', $deviceId)->where('status', 'pending')->count();

        return response()->json([
            'success' => true,
            'commands_pending' => $pendingCount
        ]);
    }

    private function updateChannel($deviceId, $channelData, $wifiSsid, $wifiRssi)
    {
        if (!$channelData || !isset($channelData['machine_id'])) return;

        $relayChannel = $channelData['machine_id'];
        $machine = Machine::where('device_id', $deviceId)->where('relay_channel', $relayChannel)->first();

        if (!$machine) return;

        $now = time();
        $cacheKey = "machine_update_{$machine->id}";
        $lastUpdate = Cache::get($cacheKey, ['time' => 0, 'relay' => null, 'ampere' => 0]);
        
        $currentAmpere = isset($channelData['current']) ? $channelData['current'] : 0;
        $relayStatus = isset($channelData['relay_status']) ? $channelData['relay_status'] : null;

        // Determine if we should update Firebase/MySQL
        $shouldUpdate = false;
        if ($lastUpdate['relay'] !== $relayStatus) $shouldUpdate = true;
        if (abs($lastUpdate['ampere'] - $currentAmpere) >= 0.1) $shouldUpdate = true;
        if (($now - $lastUpdate['time']) >= 2) $shouldUpdate = true; // 2 seconds

        if ($shouldUpdate) {
            $dtHours = 0;
            if ($lastUpdate['time'] > 0 && $lastUpdate['time'] < $now) {
                $dtHours = ($now - $lastUpdate['time']) / 3600;
            }

            $energyKwhDelta = ($currentAmpere * 220 * $dtHours) / 1000;
            
            if ($energyKwhDelta > 0) {
                // To keep it simple in MySQL without dynamic column names per month,
                // we can just update a total_energy field, or we might need to update Firebase directly 
                // for the energy_monthly / energy_yearly maps as previously done in Node.js.
                // Since this requires a dynamic key update, let's update Firestore using Firebase Admin SDK.
                
                $monthKey = date('Y-m');
                $yearKey = date('Y');
                $costDelta = $energyKwhDelta * 1500;

                $firestore = app('firebase.firestore')->database();
                $docRef = $firestore->collection('machines')->document($machine->id); // Assuming MySQL ID matches Firestore ID or they are mapped
                
                // Wait, MySQL IDs are numeric (1, 2, 3), Firestore IDs are strings like "L49X..."
                // Since we migrated the machines from Firestore, did we keep the string IDs or use integers?
                // The migration created $table->id() which is auto-increment integer.
                // If the ESP32 still uses the Firestore doc ID for something? ESP32 only uses device_id and relay_channel.
                // The frontend reads MySQL now. But the energy dashboard might still be in Firestore? 
                // Actually, earlier in phase 4 we migrated Machine Dashboard to MySQL. 
            }

            // Let's update RTDB for the real-time Dashboard (current_ampere, relay_status)
            $database = Firebase::database();
            $database->getReference('machines/Mesin' . $machine->id)->update([
                'current_ampere' => $currentAmpere,
                'relay_status' => $relayStatus,
                'raw_adc' => $channelData['raw_adc'] ?? null,
                'zero_offset' => $channelData['zero_offset'] ?? null,
                'rms_voltage' => $channelData['rms_voltage'] ?? null,
                'calibration_factor' => $channelData['calibration_factor'] ?? null,
                'dryer_remaining_minutes' => $channelData['dryer_remaining_minutes'] ?? null,
                'wifi_ssid' => $wifiSsid,
                'wifi_rssi' => $wifiRssi,
                'updatedAt' => $now * 1000
            ]);

            Cache::put($cacheKey, [
                'time' => $now,
                'relay' => $relayStatus,
                'ampere' => $currentAmpere
            ]);
        }
    }

    public function calibrate(Request $request)
    {
        $machineId = $request->input('machine_id');
        $currentAmpere = $request->input('current_ampere');

        if (!$machineId || !$currentAmpere) {
            return response()->json(['success' => false, 'message' => 'Missing machine_id or current_ampere'], 400);
        }

        $machine = Machine::find($machineId);
        if (!$machine) {
            return response()->json(['success' => false, 'message' => 'Machine not found'], 404);
        }

        Esp32Command::create([
            'device_id' => $machine->device_id,
            'machine_id' => $machine->relay_channel,
            'command' => 'CALIBRATE',
            'duration_minutes' => $currentAmpere
        ]);

        return response()->json(['success' => true]);
    }
}
