<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Category; // Adjust if your model is named differently
use App\Models\Ingredient;
use App\Models\IngredientCategory;

class IngredientController extends Controller
{
    public function ingredientFullData()
    {
        $ingredients = Ingredient::with('category:category_id,name')
            ->select('ingredient_id', 'name', 'price', 'photo', 'category_id')
            ->get()
            ->map(function ($ingredient) {
                return [
                    'id' => $ingredient->ingredient_id,
                    'name' => $ingredient->name,
                    'price' => $ingredient->price,
                    'imageUrl' => $this->getImageUrl($ingredient->photo),
                    'category' => optional($ingredient->category)->name,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $ingredients
        ]);
    }

    public function ingredientDetail($id)
    {
        $ingredient = Ingredient::with([
            'category:category_id,name',
            'supermarkets'
        ])
            ->where('ingredient_id', $id)
            ->first(['ingredient_id', 'name', 'price', 'photo', 'category_id', 'description']);

        if (!$ingredient) {
            return response()->json([
                'success' => false,
                'message' => 'Ingredient tidak ditemukan.'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $ingredient->ingredient_id,
                'name' => $ingredient->name,
                'price' => $ingredient->price,
                'imageUrl' => $this->getImageUrl($ingredient->photo),
                'category' => $ingredient->category->name ?? 'Umum',
                'description' => $ingredient->description ?? '',
                'supermarkets' => $ingredient->supermarkets->map(function ($supermarket) {
                    return [
                        'id' => $supermarket->supermarket_id,
                        'name' => $supermarket->name,
                        'address' => $supermarket->address,
                        'location' => [
                            'latitude' => $supermarket->latitude,
                            'longitude' => $supermarket->longitude
                        ],
                        'isAvailable' => $supermarket->pivot->is_available,
                        'lastUpdated' => $supermarket->pivot->last_updated
                    ];
                }),
            ]
        ]);
    }

    /**
     * Helper untuk mendapatkan URL gambar lengkap
     *
     * @param string|null $photoName
     * @return string
     */
    private function getImageUrl($photoName)
    {
        if (empty($photoName)) {
            return asset('images/placeholders/ingredient-placeholder.jpg');
        }

        // Cek apakah photo sudah berupa URL lengkap
        if (filter_var($photoName, FILTER_VALIDATE_URL)) {
            return $photoName;
        }

        // Jika bukan URL lengkap, buat URL berdasarkan nama file
        return asset('images/ingredients/' . $photoName);
    }
}
