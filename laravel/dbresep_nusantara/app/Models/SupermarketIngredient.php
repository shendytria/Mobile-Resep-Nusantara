<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SupermarketIngredient extends Model
{
    use HasFactory;

    protected $primaryKey = 'supermarket_ingredient_id';
    protected $table = 'supermarket_ingredients';

    const UPDATED_AT = null;

    protected $fillable = [
        'supermarket_id',
        'ingredient_id',
        'is_available',
    ];

    protected $casts = [
        'is_available' => 'boolean',
        'last_updated' => 'datetime',
    ];

    public function supermarket()
    {
        return $this->belongsTo(Supermarket::class, 'supermarket_id');
    }

    public function ingredient()
    {
        return $this->belongsTo(Ingredient::class, 'ingredient_id');
    }
}
