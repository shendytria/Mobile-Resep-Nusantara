<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class IngredientResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'ingredient_id' => $this->ingredient_id,
            'name' => $this->name,
            'quantity' => $this->quantity,
            'unit' => $this->unit,
        ];
    }
}
