<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Supermarket extends Model
{
    use HasFactory;

    protected $primaryKey = 'supermarket_id';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'latitude',
        'longitude',
        'address',
    ];

    protected $casts = [
        'latitude' => 'decimal:6',
        'longitude' => 'decimal:6',
    ];

    public function ingredients()
    {
        return $this->belongsToMany(Ingredient::class, 'supermarket_ingredients', 'supermarket_id', 'ingredient_id')
                    ->withPivot('is_available', 'last_updated');
    }
}
