<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id('user_id');
            $table->string('username', 50);
            $table->string('email')->unique();
            $table->string('password_hash');
            $table->string('profile_picture')->nullable();
            $table->boolean('email_verified')->default(false);
            $table->timestamps();
        });

        Schema::create('recipe_categories', function (Blueprint $table) {
            $table->id('category_id');
            $table->string('name', 50);
            $table->text('description')->nullable();
        });

        Schema::create('recipes', function (Blueprint $table) {
            $table->id('recipe_id');
            $table->foreignId('user_id')->constrained('users', 'user_id')->onDelete('cascade');
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('thumbnail_photo')->nullable();
            $table->foreignId('category_id')->nullable()->constrained('recipe_categories', 'category_id');
            $table->integer('preparation_time')->nullable();
            $table->integer('cooking_time')->nullable();
            $table->integer('servings')->nullable();
            $table->timestamps();
        });

        Schema::create('recipe_ingredients', function (Blueprint $table) {
            $table->id('ingredient_id');
            $table->foreignId('recipe_id')->constrained('recipes', 'recipe_id')->onDelete('cascade');
            $table->string('name', 100);
            $table->string('quantity')->nullable();
            $table->string('unit', 20)->nullable();
            $table->integer('position')->nullable();
        });

        Schema::create('recipe_steps', function (Blueprint $table) {
            $table->id('step_id');
            $table->foreignId('recipe_id')->constrained('recipes', 'recipe_id')->onDelete('cascade');
            $table->integer('step_number');
            $table->text('description');
        });

        Schema::create('favorites', function (Blueprint $table) {
            $table->id('favorite_id');
            $table->foreignId('user_id')->constrained('users', 'user_id')->onDelete('cascade');
            $table->foreignId('recipe_id')->constrained('recipes', 'recipe_id')->onDelete('cascade');
            $table->timestamps();
        });

        Schema::create('collections', function (Blueprint $table) {
            $table->id('collection_id');
            $table->foreignId('user_id')->constrained('users', 'user_id')->onDelete('cascade');
            $table->string('name', 100);
            $table->timestamps();
        });

        Schema::create('collection_recipe', function (Blueprint $table) {
            $table->id('collection_recipe_id');
            $table->foreignId('collection_id')->constrained('collections', 'collection_id')->onDelete('cascade');
            $table->foreignId('recipe_id')->constrained('recipes', 'recipe_id')->onDelete('cascade');
            $table->timestamp('added_at')->nullable();
        });

        Schema::create('ingredient_categories', function (Blueprint $table) {
            $table->id('category_id');
            $table->string('name', 50);
            $table->text('description')->nullable();
        });

        Schema::create('ingredients', function (Blueprint $table) {
            $table->id('ingredient_id');
            $table->string('name', 100);
            $table->decimal('price', 10, 2)->nullable();
            $table->string('photo')->nullable();
            $table->foreignId('category_id')->nullable()->constrained('ingredient_categories', 'category_id')->onDelete('set null');
            $table->timestamps();
        });

        Schema::create('supermarkets', function (Blueprint $table) {
            $table->id('supermarket_id');
            $table->string('name', 100);
            $table->decimal('latitude', 9, 6);
            $table->decimal('longitude', 9, 6);
            $table->text('address')->nullable();
        });

        Schema::create('supermarket_ingredients', function (Blueprint $table) {
            $table->id('supermarket_ingredient_id');
            $table->foreignId('supermarket_id')->constrained('supermarkets', 'supermarket_id')->onDelete('cascade');
            $table->foreignId('ingredient_id')->constrained('ingredients', 'ingredient_id')->onDelete('cascade');
            $table->boolean('is_available')->default(true);
            $table->timestamp('last_updated')->nullable();
        });

        Schema::create('email_verification_tokens', function (Blueprint $table) {
            $table->id('token_id');
            $table->foreignId('user_id')->constrained('users', 'user_id')->onDelete('cascade');
            $table->string('token');
            $table->timestamp('expires_at');
            $table->timestamps();
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->id('token_id');
            $table->foreignId('user_id')->constrained('users', 'user_id')->onDelete('cascade');
            $table->string('token');
            $table->timestamp('expires_at');
            $table->timestamps();
        });

        Schema::create('two_factor_auth', function (Blueprint $table) {
            $table->id('tfa_id');
            $table->foreignId('user_id')->constrained('users', 'user_id')->onDelete('cascade');
            $table->string('method', 20);
            $table->string('secret', 100);
            $table->boolean('is_enabled')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('two_factor_auth');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('email_verification_tokens');
        Schema::dropIfExists('supermarket_ingredients');
        Schema::dropIfExists('supermarkets');
        Schema::dropIfExists('ingredient_categories');
        Schema::dropIfExists('ingredients');
        Schema::dropIfExists('collection_recipe');
        Schema::dropIfExists('collections');
        Schema::dropIfExists('favorites');
        Schema::dropIfExists('recipe_steps');
        Schema::dropIfExists('recipe_ingredients');
        Schema::dropIfExists('recipe_categories');
        Schema::dropIfExists('recipes');
        Schema::dropIfExists('users');
    }
};
