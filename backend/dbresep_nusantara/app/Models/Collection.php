<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Collection extends Model
{
    use HasFactory;

    protected $primaryKey = 'collection_id';
    public $incrementing = true; // jika kolom PK auto-increment
    protected $keyType = 'int';

    const UPDATED_AT = null;

    protected $fillable = [
        'user_id',
        'name',
    ];

    protected $casts = [
        'created_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function recipes()
    {
        return $this->belongsToMany(Recipe::class, 'collection_recipe', 'collection_id', 'recipe_id')
            ->withPivot('added_at');
    }
}
