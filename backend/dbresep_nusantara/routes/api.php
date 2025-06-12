<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\RecipeController;
use App\Http\Controllers\API\CollectionController;
use App\Http\Controllers\API\CategoryController;
use App\Http\Controllers\API\IngredientController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');


/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/

// Public routes
Route::post('register', [AuthController::class, 'register']);//dah
Route::post('login', [AuthController::class, 'login'])->name('login');//dah
// Route::post('verify-email', [AuthController::class, 'verifyEmail']);
Route::post('forgot-password', [AuthController::class, 'forgotPassword']);
// Route::post('reset-password', [AuthController::class, 'resetPassword']);
// Route::post('verify-2fa', [AuthController::class, 'verify2FA']);

Route::get('recipecategories', [CategoryController::class, 'recipecategories']);//dah
Route::get('ingredientcategories', [CategoryController::class, 'ingredientcategories']);//dah
Route::get('ingredients/full', [IngredientController::class, 'ingredientFullData']);//dah
Route::get('ingredient/{id}', [IngredientController::class, 'ingredientDetail']);//dah

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    // Auth routes
    Route::post('logout', [AuthController::class, 'logout']);//dah
    Route::get('user', [AuthController::class, 'user']);//dah
    Route::put('/user/{id}', [AuthController::class, 'update']);//dah
    // Route::post('setup-2fa', [AuthController::class, 'setup2FA']);
    // Route::post('enable-2fa', [AuthController::class, 'enable2FA']);
    // Route::post('disable-2fa', [AuthController::class, 'disable2FA']);

    // Recipe routes
    Route::post('/recipes', [RecipeController::class, 'store']); // dah Menambah resep
    Route::get('/recipes', [RecipeController::class, 'index']); // dah Daftar semua resep
    Route::get('/recipes/{id}', [RecipeController::class, 'show']); // dah Detail resep
    Route::put('/recipes/{id}', [RecipeController::class, 'update']); // dah Update resep
    Route::delete('/recipes/{id}', [RecipeController::class, 'destroy']); // dah Hapus resep
    Route::post('/recipes/{id}/favorite', [RecipeController::class, 'toggleFavorite']); // dah Toggle favorite
    Route::get('/favorites', [RecipeController::class, 'getFavorites']); //dah Daftar resep favorit
    Route::post('/toggle-collection', [RecipeController::class, 'toggleCollection']); //dah Toggle koleksi resep
    Route::get('/collections/recipes', [RecipeController::class, 'getCollections']); //dah
    Route::delete('/collections/{collectionId}/recipes/{recipeId}', [RecipeController::class, 'removeRecipeFromCollection']); //dah

    // Collection routes
    Route::get('collections', [CollectionController::class, 'index']); //dah
    Route::post('collections', [CollectionController::class, 'store']); //dah
    // Route::get('collections/{id}', [CollectionController::class, 'show']);
    Route::put('collections/{id}', [CollectionController::class, 'update']); //dah
    Route::delete('collections/{id}', [CollectionController::class, 'destroy']); //dah
});
