<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Recipe extends Model
{
    use HasFactory;

    protected $primaryKey = 'recipe_id';

    protected $fillable = [
        'user_id',
        'title',
        'description',
        'thumbnail_photo',
        'category_id',
        'preparation_time',
        'cooking_time',
        'servings',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function category()
    {
        return $this->belongsTo(RecipeCategory::class, 'category_id');
    }

    public function ingredients()
    {
        return $this->hasMany(RecipeIngredient::class, 'recipe_id');
    }

    public function steps()
    {
        return $this->hasMany(RecipeStep::class, 'recipe_id')->orderBy('step_number');
    }

    public function favorites()
    {
        return $this->belongsToMany(User::class, 'favorites', 'recipe_id', 'user_id')
                    ->withTimestamps();
    }

    public function collections()
    {
        return $this->belongsToMany(Collection::class, 'collection_recipe', 'recipe_id', 'collection_id')
                    ->withTimestamps('added_at');
    }
}
