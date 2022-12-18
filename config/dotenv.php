<?php

use Symfony\Component\Dotenv\Dotenv;

$dotEnv = (new Dotenv())->usePutenv();

$envs = ['.env', '.env.local'];
if ((true === \array_key_exists('APP_ENV', $_SERVER) && 'test' === $_SERVER['APP_ENV'])
    || (true === \array_key_exists('APP_ENV', $_ENV) && 'test' === $_ENV['APP_ENV'])
) {
    $envs = \array_merge($envs, ['.env.test', '.env.test.local']);
}

$envValues = [];
foreach ($envs as $env) {
    $path = \dirname(__DIR__) . '/' . $env;

    if (false === \is_file($path)) {
        continue;
    }

    $envValues = \array_merge(
        $envValues,
        $dotEnv->parse((string) file_get_contents($path))
    );
}

$dotEnv->populate($envValues, true);
