<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RecipeCategory extends Model
{
    use HasFactory;

    protected $primaryKey = 'category_id';
    protected $table = 'recipe_categories';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'description',
    ];

    public function recipes()
    {
        return $this->hasMany(Recipe::class, 'category_id');
    }
}
