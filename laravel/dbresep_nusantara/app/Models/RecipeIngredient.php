<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RecipeIngredient extends Model
{
    use HasFactory;

    protected $primaryKey = 'ingredient_id';
    protected $table = 'recipe_ingredients';

    public $timestamps = false;

    protected $fillable = [
        'recipe_id',
        'name',
        'quantity',
        'unit',
        'position',
    ];

    public function recipe()
    {
        return $this->belongsTo(Recipe::class, 'recipe_id');
    }
}
