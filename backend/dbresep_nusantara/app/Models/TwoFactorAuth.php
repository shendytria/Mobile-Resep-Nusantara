<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class TwoFactorAuth extends Model
{
    use HasFactory;

    protected $primaryKey = 'tfa_id';
    protected $table = 'two_factor_auth';

    protected $fillable = [
        'user_id',
        'method',
        'secret',
        'is_enabled',
    ];

    protected $casts = [
        'is_enabled' => 'boolean',
        'created_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
