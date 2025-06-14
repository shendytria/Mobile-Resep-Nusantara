<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RecipeStep extends Model
{
    use HasFactory;

    protected $primaryKey = 'step_id';
    protected $table = 'recipe_steps';

    public $timestamps = false;

    protected $fillable = [
        'recipe_id',
        'step_number',
        'description',
    ];

    public function recipe()
    {
        return $this->belongsTo(Recipe::class, 'recipe_id');
    }
}
