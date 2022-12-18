#-include docker/.env

CONTAINER ?= php
NO_RESET ?= n
NO_CLEAR_CACHE ?= n
COVERAGE_CHECKER ?= y
DISABLE_XDEBUG = XDEBUG_MODE=off
.SILENT: is_test_container shell shell-test reset analyse clear-cache phpunit
.DEFAULT_GOAL := help

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

##
## Project
##---------------------------------------------------------------------------

install: ## Install the project
install: hooks
	cd ./docker && ./install.sh

start: ## Start the project
start: hooks
	cd ./docker && ./start.sh
	sleep 5 && make queues

stop: ## Stop the project
stop:
	cd ./docker && ./stop.sh

queues:
	cd ./docker && docker-compose exec -T php bin/console messenger:setup-transports
	cd ./docker && docker-compose exec -T php_test bin/console messenger:setup-transports

restart: ## Restart the project
restart: stop start

hooks:
	# Pre commit
	echo "#!/bin/bash" > .git/hooks/pre-commit
	echo "make check" >> .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	# Git pull
	echo "#!/bin/bash" > .git/hooks/post-merge
	echo "make post-merge" >> .git/hooks/post-merge
	chmod +x .git/hooks/post-merge

post-merge: composer
	cd ./docker/ && docker-compose exec -T $(CONTAINER) make doctrine-migrations

composer:
	cd ./docker && docker-compose exec -T $(CONTAINER) bash -c "composer install"

shell: ## Connect to PHP container
shell:
	cd ./docker && docker-compose exec $(CONTAINER) bash

shell-test: ## Connect to PHP test container
shell-test:
	make shell CONTAINER=php_test

warmup-cache:
	bin/console cache:warmup

clear-cache:
	if [ "$(NO_CLEAR_CACHE)" = "y" ];then \
      		echo "\033[0;34mSkip clear cache.\033[0;0m"; \
	else \
		$(DISABLE_XDEBUG) bin/console cache:clear --no-warmup; \
	fi;

##
## Database
##---------------------------------------------------------------------------

reset: ## Reset the database (only on container)
reset:
	if [ "$(NO_RESET)" = "y" ];then \
  		echo "\033[0;34mSkip reset database.\033[0;0m"; \
	else \
		$(DISABLE_XDEBUG) bin/console doctrine:database:drop --if-exists --force; \
		make doctrine-migrations; \
		$(DISABLE_XDEBUG) bin/console doctrine:fixtures:load --no-interaction; \
		$(DISABLE_XDEBUG) bin/console messenger:setup-transports; \
	fi;

doctrine-migrations: ## Execute all migrations (only on container)
doctrine-migrations:
	$(DISABLE_XDEBUG) bin/console doctrine:database:create --if-not-exists
	$(DISABLE_XDEBUG) bin/console doctrine:migration:migrate --allow-no-migration --no-interaction --all-or-nothing

##
## xDebug (only for PHP container)
##---------------------------------------------------------------------------

xdebug-enable: ## Enable xDebug
xdebug-enable:
	cd ./docker && docker-compose exec -T -u 0 php docker-php-ext-enable xdebug
	cd ./docker && docker-compose exec -T -u 0 php bash -c "kill -USR2 1"

xdebug-disable: ## Disable xDebug
xdebug-disable:
	cd ./docker && docker-compose exec -T -u 0 php sed -i '/zend_extension/d' /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
	cd ./docker && docker-compose exec -T -u 0 php bash -c "kill -USR2 1"

##
## Code quality (only on PHP test container)
##---------------------------------------------------------------------------

is_test_container:
	if [ "$(APP_ENV)" != "test" ];then \
		echo "\033[0;31mAll tests must be execute into php_test container.\033[0;0m"; \
		exit 1; \
	fi

check: queues
	cd ./docker/ && docker-compose exec -T php_test make clear-cache
	cd ./docker/ && docker-compose exec -T php_test make lint
	cd ./docker/ && docker-compose exec -T php_test make analyse
	cd ./docker/ && docker-compose exec -T php_test make copy-paste
	cd ./docker/ && docker-compose exec -T php_test make doctrine
	cd ./docker/ && docker-compose exec -T php_test make security

lint: ## Execute PHPCS
lint: is_test_container
	$(DISABLE_XDEBUG) vendor/bin/phpcs -p --report-full --report-checkstyle=./phpcs-report.xml

fixer: ## Execute PHPCS fixer
fixer: is_test_container
	$(DISABLE_XDEBUG) ./vendor/bin/phpcbf -p

analyse: ## Execute PHPStan
analyse: is_test_container
	if [ "$(NO_CLEAR_CACHE)" != "y" ];then \
		$(DISABLE_XDEBUG) bin/console cache:warmup --env=dev; \
		$(DISABLE_XDEBUG) bin/console cache:warmup --env=test; \
  	fi
	vendor/bin/phpstan analyse --memory-limit=4G

doctrine: ## Validate Doctrine schema
doctrine: is_test_container reset
	$(DISABLE_XDEBUG) bin/console d:s:v --env=test
	$(DISABLE_XDEBUG) bin/console d:s:u --dump-sql --env=test

phpunit: ## Execute PHPUnit test suites
phpunit: is_test_container clear-cache reset
	rm -rf ./var/coverage_backup/
	mkdir -p ./var/coverage_backup/
	mkdir -p ./var/coverage/
	touch ./var/coverage/COVERAGE
	mv -f ./var/coverage/* ./var/coverage_backup/
	./vendor/bin/simple-phpunit \
		--coverage-html=var/coverage/ \
		--coverage-xml=var/coverage/xml \
		--log-junit=var/coverage/junit.xml
	if [ "$(COVERAGE_CHECKER)" = "y" ];then \
  		make coverage-checker; \
  	fi;

copy-paste: ## Check duplicate code
copy-paste: is_test_container
	$(DISABLE_XDEBUG) ./bin/phpcpd src \
		--fuzzy

coverage-checker:
	$(DISABLE_XDEBUG) ./vendor/bin/coverage-checker var/coverage/xml/index.xml 80

security: ## Check CVE for vendor dependencies
security: is_test_container
	./bin/security-checker --path=./composer.lock
