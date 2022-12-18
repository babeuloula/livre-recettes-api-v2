<?php

ini_set('error_reporting', E_ALL & ~E_NOTICE & ~E_DEPRECATED);
putenv("APP_ENV=test");

require \dirname(__DIR__) . '/vendor/autoload.php';
require \dirname(__DIR__) . '/config/dotenv.php';
