<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class IngredientCategory extends Model
{
    use HasFactory;

    protected $primaryKey = 'category_id';
    protected $table = 'ingredient_categories';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'description',
    ];

    public function ingredients()
    {
        return $this->hasMany(Ingredient::class, 'category_id');
    }
}
