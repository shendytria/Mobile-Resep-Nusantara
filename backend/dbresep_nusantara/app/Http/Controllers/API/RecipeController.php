<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Recipe;
use App\Models\RecipeIngredient;
use App\Models\RecipeStep;
use App\Models\Favorite;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use App\Http\Resources\RecipeResource;
use App\Models\CollectionRecipe;
use App\Models\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class RecipeController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'thumbnail_photo' => 'nullable|image|max:2048',
            'category_id' => 'nullable|integer|exists:recipe_categories,category_id',
            'preparation_time' => 'nullable|integer|min:0',
            'cooking_time' => 'nullable|integer|min:0',
            'servings' => 'nullable|integer|min:1',
            'ingredients' => 'required|array|min:1',
            'ingredients.*.name' => 'required|string|max:100',
            'ingredients.*.quantity' => 'nullable|string|max:50',
            'ingredients.*.unit' => 'nullable|string|max:20',
            'steps' => 'required|array|min:1',
            'steps.*.step_number' => 'required|integer|min:1',
            'steps.*.description' => 'required|string',
        ]);

        // Upload thumbnail jika ada
        if ($request->hasFile('thumbnail_photo')) {
            $data['thumbnail_photo'] = $request->file('thumbnail_photo')->store('recipes/thumbnails', 'public');
        }

        // Set user_id pemilik resep
        $data['user_id'] = $request->user()->user_id;

        // Simpan data utama resep
        $recipe = Recipe::create([
            'user_id' => $data['user_id'],
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'thumbnail_photo' => $data['thumbnail_photo'] ?? null,
            'category_id' => $data['category_id'] ?? null,
            'preparation_time' => $data['preparation_time'] ?? null,
            'cooking_time' => $data['cooking_time'] ?? null,
            'servings' => $data['servings'] ?? null,
        ]);

        // Simpan bahan-bahan
        foreach ($data['ingredients'] as $i => $ingredient) {
            RecipeIngredient::create([
                'recipe_id' => $recipe->recipe_id,
                'name' => $ingredient['name'],
                'quantity' => $ingredient['quantity'] ?? null,
                'unit' => $ingredient['unit'] ?? null,
                'position' => $i + 1,
            ]);
        }

        // Simpan langkah-langkah
        foreach ($data['steps'] as $step) {
            RecipeStep::create([
                'recipe_id' => $recipe->recipe_id,
                'step_number' => $step['step_number'],
                'description' => $step['description'],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Resep berhasil ditambahkan',
            'data' => $recipe->load(['ingredients', 'steps', 'category'])
        ], 201);
    }

    public function index(Request $request)
    {
        $perPage = $request->input('per_page', 10);
        $categoryId = $request->input('category_id');

        $query = Recipe::with([
            'user:user_id,username',
            'category:category_id,name',
            'ingredients:ingredient_id,recipe_id,name,quantity,unit,position', // Tambahkan ingredients
            'steps:step_id,recipe_id,step_number,description' // Tambahkan steps
        ]);

        if ($categoryId) {
            $query->where('category_id', $categoryId);
        }

        $recipes = $query->orderBy('created_at', 'desc')->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => RecipeResource::collection($recipes)
        ]);
    }

    public function show(Request $request, $id)
    {
        // Ambil resep beserta relasi
        $recipe = Recipe::with([
            'user:user_id,username',
            'category:category_id,name',
            'ingredients' => function ($q) {
                $q->orderBy('position', 'asc');
            },
            'steps' => function ($q) {
                $q->orderBy('step_number', 'asc');
            }
        ])->find($id);

        // Cek apakah resep ditemukan
        if (!$recipe) {
            return response()->json([
                'success' => false,
                'message' => 'Resep tidak ditemukan'
            ], 404);
        }

        // Tambahkan status favorit dan koleksi jika user login
        if ($request->user()) {
            $userId = $request->user()->user_id;
            $recipe->is_favorited = Favorite::where('user_id', $userId)
                ->where('recipe_id', $id)
                ->exists();

            // Tambahkan status isInCollection
            $recipe->isInCollection = CollectionRecipe::where('recipe_id', $id)
                ->whereIn('collection_id', function ($query) use ($userId) {
                    $query->select('collection_id')
                        ->from('collections')
                        ->where('user_id', $userId);
                })
                ->exists();
        } else {
            $recipe->is_favorited = false;
            $recipe->isInCollection = false; // Default untuk user yang tidak login
        }

        return response()->json([
            'success' => true,
            'data' => $recipe
        ], 200);
    }

    public function update(Request $request, $id)
    {
        $recipe = Recipe::find($id);

        if (!$recipe) {
            return response()->json(['success' => false, 'message' => 'Resep tidak ditemukan'], 404);
        }

        if ($recipe->user_id !== $request->user()->user_id) {
            return response()->json(['success' => false, 'message' => 'Tidak diizinkan'], 403);
        }

        $data = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'thumbnail_photo' => 'nullable|image|max:2048',
            'category_id' => 'nullable|integer|exists:recipe_categories,category_id',
            'preparation_time' => 'nullable|integer|min:0',
            'cooking_time' => 'nullable|integer|min:0',
            'servings' => 'nullable|integer|min:1',
            'ingredients' => 'required|array|min:1',
            'ingredients.*.name' => 'required|string|max:100',
            'ingredients.*.quantity' => 'nullable|string|max:50',
            'ingredients.*.unit' => 'nullable|string|max:20',
            'steps' => 'required|array|min:1',
            'steps.*.step_number' => 'required|integer|min:1',
            'steps.*.description' => 'required|string',
        ]);

        if ($request->hasFile('thumbnail_photo')) {
            if ($recipe->thumbnail_photo) {
                Storage::disk('public')->delete($recipe->thumbnail_photo);
            }
            $data['thumbnail_photo'] = $request->file('thumbnail_photo')->store('recipes/thumbnails', 'public');
        }

        $recipe->update([
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'thumbnail_photo' => $data['thumbnail_photo'] ?? $recipe->thumbnail_photo,
            'category_id' => $data['category_id'] ?? null,
            'preparation_time' => $data['preparation_time'] ?? null,
            'cooking_time' => $data['cooking_time'] ?? null,
            'servings' => $data['servings'] ?? null,
        ]);

        // Hapus dan ganti bahan & langkah
        $recipe->ingredients()->delete();
        foreach ($data['ingredients'] as $i => $ingredient) {
            RecipeIngredient::create([
                'recipe_id' => $recipe->recipe_id,
                'name' => $ingredient['name'],
                'quantity' => $ingredient['quantity'] ?? null,
                'unit' => $ingredient['unit'] ?? null,
                'position' => $i + 1,
            ]);
        }

        $recipe->steps()->delete();
        foreach ($data['steps'] as $step) {
            RecipeStep::create([
                'recipe_id' => $recipe->recipe_id,
                'step_number' => $step['step_number'],
                'description' => $step['description'],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Resep berhasil diperbarui',
            'data' => $recipe->load(['ingredients', 'steps', 'category'])
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $recipe = Recipe::find($id);

        if (!$recipe) {
            return response()->json(['success' => false, 'message' => 'Resep tidak ditemukan'], 404);
        }

        if ($recipe->user_id !== $request->user()->user_id) {
            return response()->json(['success' => false, 'message' => 'Tidak diizinkan menghapus resep ini'], 403);
        }

        if ($recipe->thumbnail_photo) {
            Storage::disk('public')->delete($recipe->thumbnail_photo);
        }

        $recipe->delete();

        return response()->json([
            'success' => true,
            'message' => 'Resep berhasil dihapus'
        ]);
    }

    public function toggleFavorite(Request $request, $id)
    {
        $recipe = Recipe::find($id);

        if (!$recipe) {
            return response()->json(['success' => false, 'message' => 'Resep tidak ditemukan'], 404);
        }

        $userId = $request->user()->user_id;

        $favorite = Favorite::where('user_id', $userId)
            ->where('recipe_id', $id)
            ->first();

        if ($favorite) {
            $favorite->delete();
            $status = false;
        } else {
            Favorite::create([
                'user_id' => $userId,
                'recipe_id' => $id
            ]);
            $status = true;
        }

        return response()->json([
            'success' => true,
            'message' => $status ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit',
            'is_favorited' => $status
        ]);
    }

    public function getFavorites(Request $request)
    {
        $perPage = $request->input('per_page', 10);
        $categoryId = $request->input('category_id');

        $userId = $request->user()->user_id;
        if (!$userId) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $query = Recipe::whereHas('favorites', function ($query) use ($userId) {
            $query->where('favorites.user_id', $userId); // ← sebutkan nama tabel
        })->with([
            'user:user_id,username',
            'category:category_id,name',
            'ingredients:ingredient_id,recipe_id,name,quantity,unit,position',
            'steps:step_id,recipe_id,step_number,description'
        ]);

        if ($categoryId) {
            $query->where('category_id', $categoryId);
        }

        $favorites = $query->orderBy('recipes.created_at', 'desc') // ← spesifik dari tabel recipes
            ->paginate($perPage);

        return response()->json([
            'success' => true,
            'data' => RecipeResource::collection($favorites)
        ], 200);
    }

    public function toggleCollection(Request $request)
    {
        try {
            $userId = $request->user()->user_id;
            $recipeId = $request->input('recipe_id');
            $collectionId = $request->input('collection_id');

            // Pastikan user memiliki koleksi tersebut
            $collection = Collection::where('user_id', $userId)
                ->where('collection_id', $collectionId)
                ->first();

            if (!$collection) {
                return response()->json([
                    'success' => false,
                    'message' => 'Collection not found or you do not have access.',
                ], 404);
            }

            // Cek apakah resep sudah ada di koleksi (pivot)
            $existing = CollectionRecipe::where('collection_id', $collectionId)
                ->where('recipe_id', $recipeId)
                ->first();

            if ($existing) {
                $existing->delete();
                return response()->json([
                    'success' => true,
                    'message' => 'Recipe removed from collection.',
                    'is_in_collection' => false,
                ], 200);
            } else {
                CollectionRecipe::create([
                    'collection_id' => $collectionId,
                    'recipe_id' => $recipeId,
                ]);
                return response()->json([
                    'success' => true,
                    'message' => 'Recipe added to collection.',
                    'is_in_collection' => true,
                ], 200);
            }
        } catch (\Exception $e) {
            Log::error('Toggle Collection Error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'An error occurred: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function getCollections(Request $request)
    {
        $perPage = $request->input('per_page', 10);

        $collections = Collection::where('user_id', $request->user()->user_id)
            ->with(['recipes' => function ($query) {
                $query->with([
                    'user:user_id,username',
                    'category:category_id,name',
                    'ingredients:ingredient_id,recipe_id,name,quantity,unit,position',
                    'steps:step_id,recipe_id,step_number,description'
                ]);
            }])
            ->paginate($perPage);

        // Tambahkan collection_recipe_id dan added_at secara manual
        foreach ($collections as $collection) {
            foreach ($collection->recipes as $recipe) {
                $pivot = CollectionRecipe::where('collection_id', $collection->collection_id)
                    ->where('recipe_id', $recipe->recipe_id)
                    ->first();

                $recipe->collection_recipe_id = $pivot->collection_recipe_id ?? null;
                $recipe->added_at = $pivot->created_at ?? null; // Ubah 'added_at' menjadi 'created_at'
            }
        }

        return response()->json([
            'success' => true,
            'data' => $collections
        ], 200);
    }

    public function removeRecipeFromCollection(Request $request, $collectionId, $recipeId)
    {
        // Ambil collectionId dan recipeId langsung dari parameter rute
        $collection = Collection::where('collection_id', $collectionId)
            ->where('user_id', Auth::id())
            ->first();

        if (!$collection) {
            return response()->json([
                'success' => false,
                'message' => 'Koleksi tidak ditemukan atau Anda tidak memiliki akses.'
            ], 404);
        }

        $pivot = CollectionRecipe::where('collection_id', $collectionId)
            ->where('recipe_id', $recipeId)
            ->first();

        if (!$pivot) {
            return response()->json([
                'success' => false,
                'message' => 'Resep tidak ditemukan dalam koleksi ini.'
            ], 404);
        }

        $pivot->delete();

        return response()->json([
            'success' => true,
            'message' => 'Resep berhasil dihapus dari koleksi.'
        ], 200);
    }
}
