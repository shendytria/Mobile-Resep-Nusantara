<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class RecipeResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'recipe_id' => $this->recipe_id,
            'title' => $this->title,
            'description' => $this->description,
            'thumbnail_photo' => $this->thumbnail_photo
                ? asset('storage/' . $this->thumbnail_photo)
                : null,
            'preparation_time' => $this->preparation_time,
            'cooking_time' => $this->cooking_time,
            'servings' => $this->servings,
            'category' => $this->category->name ?? null,
            'user' => [
                'id' => $this->user->user_id,
                'username' => $this->user->username,
            ],
            'ingredients' => IngredientResource::collection($this->whenLoaded('ingredients')),
            'steps' => StepResource::collection($this->whenLoaded('steps')),
            'created_at' => $this->created_at,
        ];
    }
}
