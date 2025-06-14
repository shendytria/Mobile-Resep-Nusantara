<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Storage;

Route::get('/storage/{filename}', function ($filename) {
    $path = storage_path('app/public/' . $filename);
    if (file_exists($path)) {
        return response()->file($path);
    }
    abort(404);
})->where('filename', '.*')->middleware('cors.images');
