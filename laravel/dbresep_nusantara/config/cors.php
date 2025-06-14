<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'storage/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'allowed_origins_patterns' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
