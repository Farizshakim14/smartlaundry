<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Machine extends Model
{
    protected $fillable = [
        'store_id',
        'device_id',
        'relay_channel',
        'name',
        'type',
        'status',
        'price'
    ];
}
