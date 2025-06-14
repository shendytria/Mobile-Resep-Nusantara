<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Collection;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;

class CollectionController extends Controller
{
    public function index(Request $request)
    {
        $collections = Collection::where('user_id', $request->user()->user_id)
            ->with(['recipes' => function ($query) {
                $query->select('recipes.recipe_id', 'thumbnail_photo', 'collection_recipe.collection_id') // Tambahkan collection_id jika perlu
                    ->orderBy('recipes.created_at', 'asc'); // Ambil urutan paling awal -> paling akhir
            }])
            ->withCount('recipes')
            ->orderBy('created_at', 'desc')
            ->get();

        // Ambil recipe terakhir dari setiap koleksi
        $collections->each(function ($collection) {
            if ($collection->recipes->isNotEmpty()) {
                $thumbnail = $collection->recipes->last()->thumbnail_photo;
                $collection->thumbnail_url = $thumbnail
                    ? Storage::url($thumbnail)
                    : null;
            }
        });

        return response()->json([
            'success' => true,
            'data' => $collections
        ], 200);
    }

    /**
     * Store a newly created collection
     */
    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
        ]);

        $collection = Collection::create([
            'user_id' => $request->user()->user_id,
            'name' => $data['name'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Koleksi berhasil dibuat',
            'data' => $collection
        ], 201);
    }

    /**
     * Display the specified collection with its recipes
     */
    public function show(Request $request, $id)
    {
        $perPage = $request->input('per_page', 10);

        $collection = Collection::where('user_id', $request->user()->user_id)
            ->where('collection_id', $id)
            ->with([
                'recipes' => function ($query) use ($perPage) {
                    $query->with([
                        'user:user_id,username',
                        'category:category_id,name',
                        'ingredients:ingredient_id,recipe_id,name,quantity,unit,position',
                        'steps:step_id,recipe_id,step_number,description'
                    ])
                        ->select('recipes.recipe_id', 'thumbnail_photo', 'title', 'description') // Tambahkan field yang dibutuhkan
                        ->orderBy('collection_recipe.created_at', 'desc')
                        ->paginate($perPage);
                }
            ])
            ->first();

        if (!$collection) {
            return response()->json([
                'success' => false,
                'message' => 'Koleksi tidak ditemukan'
            ], 404);
        }

        // Tambahkan URL gambar lengkap untuk koleksi (jika ada thumbnail dari resep pertama)
        if ($collection->recipes->isNotEmpty()) {
            $thumbnail = $collection->recipes->first()->thumbnail_photo;
            $collection->thumbnail_url = $thumbnail
                ? Storage::url($thumbnail)
                : null;
        }

        return response()->json([
            'success' => true,
            'data' => $collection
        ], 200);
    }

    /**
     * Update the specified collection
     */
    public function update(Request $request, $id)
    {
        $data = $request->validate([
            'name' => 'required|string|max:100',
        ]);

        $collection = Collection::where('user_id', $request->user()->user_id)
            ->where('collection_id', $id)
            ->first();

        if (!$collection) {
            return response()->json([
                'success' => false,
                'message' => 'Koleksi tidak ditemukan'
            ], 404);
        }

        $collection->update(['name' => $data['name']]);

        return response()->json([
            'success' => true,
            'message' => 'Koleksi berhasil diperbarui',
            'data' => $collection
        ], 200);
    }

    /**
     * Remove the specified collection
     */
    public function destroy(Request $request, $id)
    {
        $collection = Collection::where('user_id', $request->user()->user_id)
            ->where('collection_id', $id)
            ->first();

        if (!$collection) {
            return response()->json([
                'success' => false,
                'message' => 'Koleksi tidak ditemukan'
            ], 404);
        }

        $collection->delete();

        return response()->json([
            'success' => true,
            'message' => 'Koleksi berhasil dihapus'
        ], 200);
    }
}
