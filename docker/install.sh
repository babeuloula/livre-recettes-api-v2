#!/usr/bin/env bash

set -e

readonly DOCKER_PATH=$(dirname $(realpath $0))
cd ${DOCKER_PATH};

. ./lib/functions.sh

block_info "Welcome to Recipes Book installer!"

check_requirements
parse_env ".env.dist" ".env"
. ./.env
echo -e "${GREEN}Configuration done!${RESET}" > /dev/tty

# Install SSL certificates for dev
./mkcert.sh

block_info "Build & start Docker"
# Pull all container in parallel to optimize your time
docker-compose pull
./stop.sh
./start.sh
echo -e "${GREEN}Docker is started with success!${RESET}" > /dev/tty

block_info "Install dependencies"
install_composer
echo -e "${GREEN}Dependencies installed with success!${RESET}" > /dev/tty

add_host "${HTTP_HOST}"

wait_database
database_and_migrations

wait_database "test"
database_and_migrations "test"

block_info "Prepare Recipes Book"
docker-compose exec php php bin/console lexik:jwt:generate-keypair --skip-if-exists --no-interaction
echo -e "${GREEN}JWT keys generated with success!${RESET}" > /dev/tty
docker-compose exec php php bin/console doctrine:fixtures:load --no-interaction
docker-compose exec php_test php bin/console doctrine:fixtures:load --no-interaction
echo -e "${GREEN}Fixtures installed with success!${RESET}" > /dev/tty
docker-compose exec php php bin/console messenger:setup-transports --quiet
echo -e "${GREEN}Queues set up with success!${RESET}" > /dev/tty

block_success "Recipes Book is started https://${HTTP_HOST}"
