<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Ingredient extends Model
{
    use HasFactory;

    /**
     * Nama kolom primary key
     */
    protected $primaryKey = 'ingredient_id';

    /**
     * Kolom yang bisa diisi secara massal
     */
    protected $fillable = [
        'name',
        'price',
        'photo',
        'description',
        'category_id'
    ];

    /**
     * Relasi dengan ingredient_categories
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function category()
    {
        return $this->belongsTo(IngredientCategory::class, 'category_id', 'category_id');
    }

    /**
     * Relasi dengan supermarkets melalui supermarket_ingredients
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsToMany
     */
    public function supermarkets()
    {
        return $this->belongsToMany(Supermarket::class, 'supermarket_ingredients', 'ingredient_id', 'supermarket_id')
            ->withPivot('supermarket_ingredient_id', 'is_available', 'last_updated');
    }
}
