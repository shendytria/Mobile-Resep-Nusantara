<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Category; // Adjust if your model is named differently
use App\Models\Ingredient;
use App\Models\RecipeCategory;
use App\Models\IngredientCategory;
use Illuminate\Http\Request;

class CategoryController extends Controller
{
    /**
     * Get all categories
     */
    public function recipecategories(Request $request)
    {
        $categories = RecipeCategory::select('category_id', 'name', 'description')
            ->get()
            ->map(function ($category) {
                return [
                    'category_id' => $category->category_id,
                    'name' => $category->name,
                    'description' => $category->description,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $categories
        ], 200);
    }

    public function ingredientcategories(Request $request)
    {
        $categories = IngredientCategory::select('category_id', 'name', 'description')
            ->get()
            ->map(function ($category) {
                return [
                    'category_id' => $category->category_id,
                    'name' => $category->name,
                    'description' => $category->description,
                ];
            });

        return response()->json([
            'success' => true,
            'data' => $categories
        ], 200);
    }
}
