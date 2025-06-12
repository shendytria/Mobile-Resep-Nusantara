<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class StepResource extends JsonResource
{
    public function toArray($request)
    {
        return [
            'step_id' => $this->step_id,
            'order' => $this->order,
            'instruction' => $this->instruction,
        ];
    }
}
