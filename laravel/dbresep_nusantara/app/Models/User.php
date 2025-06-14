<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

// Model User
class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $primaryKey = 'user_id';

    protected $fillable = [
        'username',
        'email',
        'password_hash',
        'profile_picture',
        'email_verified'
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected $casts = [
        'email_verified' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Relasi ke resep
    public function recipes()
    {
        return $this->hasMany(Recipe::class, 'user_id');
    }

    // Relasi ke favorit
    public function favorites()
    {
        return $this->hasMany(Favorite::class, 'user_id');
    }

    // Relasi ke koleksi
    public function collections()
    {
        return $this->hasMany(Collection::class, 'user_id');
    }

    // Relasi ke two factor auth
    public function twoFactorAuth()
    {
        return $this->hasOne(TwoFactorAuth::class, 'user_id');
    }

    // Relasi ke resep favorit
    public function favoritedRecipes()
    {
        return $this->belongsToMany(Recipe::class, 'favorites', 'user_id', 'recipe_id')
                    ->withTimestamps('created_at');
    }
}
