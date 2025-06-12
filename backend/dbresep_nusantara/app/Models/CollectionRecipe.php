<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class CollectionRecipe extends Model
{
    use HasFactory;

    protected $primaryKey = 'collection_recipe_id';
    protected $table = 'collection_recipe';

    public $timestamps = false; // <-- TAMBAHKAN INI
    const UPDATED_AT = null;

    protected $fillable = [
        'collection_id',
        'recipe_id',
    ];

    protected $casts = [
        'added_at' => 'datetime',
    ];

    public function collection()
    {
        return $this->belongsTo(Collection::class, 'collection_id');
    }

    public function recipe()
    {
        return $this->belongsTo(Recipe::class, 'recipe_id');
    }
}
