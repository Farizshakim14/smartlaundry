<?php

namespace App\Http\Controllers;

use App\Models\Machine;
use App\Models\Esp32Command;
use Illuminate\Http\Request;
use Kreait\Laravel\Firebase\Facades\Firebase;

class MachineController extends Controller
{
    public function index(Request $request)
    {
        $query = Machine::query();
        if ($request->has('store_id')) {
            $query->where('store_id', $request->store_id);
        }
        $machines = $query->get();
        return response()->json(['machines' => $machines]);
    }

    public function show($id)
    {
        $machine = Machine::findOrFail($id);
        return response()->json(['machine' => $machine]);
    }

    public function store(Request $request)
    {
        $validatedData = $request->validate([
            'name' => 'required|string|max:255',
            'type' => 'nullable|string',
            'status' => 'nullable|string',
            'price' => 'nullable|numeric',
            'store_id' => 'required|string',
            'device_id' => 'nullable|string',
            'relay_channel' => 'nullable|integer'
        ]);

        $machine = Machine::create($validatedData);

        return response()->json(['message' => 'Machine created', 'machine' => $machine], 201);
    }

    public function update(Request $request, $id)
    {
        $machine = Machine::findOrFail($id);

        $validatedData = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'type' => 'nullable|string',
            'status' => 'nullable|string',
            'price' => 'nullable|numeric',
            'store_id' => 'nullable|string',
            'device_id' => 'nullable|string',
            'relay_channel' => 'nullable|integer'
        ]);

        $machine->update($validatedData);

        return response()->json(['message' => 'Machine updated', 'machine' => $machine]);
    }

    public function destroy($id)
    {
        $machine = Machine::findOrFail($id);
        $machine->delete();

        return response()->json(['message' => 'Machine deleted']);
    }

    public function start(Request $request, $id)
    {
        $machine = Machine::findOrFail($id);

        $validatedData = $request->validate([
            'timer_enabled' => 'required|boolean',
            'duration_minutes' => 'required|integer',
        ]);

        $machine->update([
            'status' => 'Active'
        ]);

        // Firebase RTDB trigger
        $database = Firebase::database();
        $database->getReference('machines/Mesin' . $id)->update([
            'status' => 'Active',
            'timer_enabled' => $validatedData['timer_enabled'],
            'duration_minutes' => $validatedData['duration_minutes'],
            'start_time' => time() * 1000,
            'updatedAt' => time() * 1000,
            'relay_status' => 'OFF' // Wait for ESP32 to turn ON
        ]);

        // Queue for ESP32
        if ($machine->device_id && $machine->relay_channel) {
            Esp32Command::create([
                'device_id' => $machine->device_id,
                'machine_id' => $machine->relay_channel,
                'command' => 'START',
                'duration_minutes' => $validatedData['duration_minutes']
            ]);
        }

        return response()->json([
            'message' => 'Machine started successfully',
            'machine' => $machine
        ]);
    }

    public function stop($id)
    {
        $machine = Machine::findOrFail($id);

        $machine->update([
            'status' => 'Idle'
        ]);

        $database = Firebase::database();
        $database->getReference('machines/Mesin' . $id)->update([
            'status' => 'Idle',
            'timer_enabled' => null,
            'duration_minutes' => null,
            'start_time' => null,
            'updatedAt' => time() * 1000,
            'relay_status' => 'OFF'
        ]);

        // Queue for ESP32
        if ($machine->device_id && $machine->relay_channel) {
            Esp32Command::create([
                'device_id' => $machine->device_id,
                'machine_id' => $machine->relay_channel,
                'command' => 'STOP',
                'duration_minutes' => 0
            ]);
        }

        return response()->json([
            'message' => 'Machine stopped successfully',
            'machine' => $machine
        ]);
    }
}
