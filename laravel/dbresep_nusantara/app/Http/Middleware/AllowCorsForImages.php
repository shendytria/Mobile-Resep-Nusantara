<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\Log;

class AllowCorsForImages
{
    public function handle($request, Closure $next)
    {
        $response = $next($request);

        Log::info('Processing request for path: ' . $request->path());
        if (str_starts_with($request->path(), 'storage/')) {
            Log::info('Applying CORS for storage path: ' . $request->path());
            $response->headers->set('Access-Control-Allow-Origin', '*');
            $response->headers->set('Access-Control-Allow-Methods', 'GET, OPTIONS');
            $response->headers->set('Access-Control-Allow-Headers', 'Content-Type');

            if ($request->getMethod() === 'OPTIONS') {
                return response('', 204);
            }
        }

        return $response;
    }
}
