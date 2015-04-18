sqlcached
==============

Sqlcached is a Node.js HTTP server that provides a REST interface to cache
MySQL queries.

## Usage

### Compile
`npm install && npm run compile`

### Run
Configure your databases and Redis server in `config/database.yml` and
`config/redis.yml`

Start the server with
`node index.js`

### Run the specs
`npm run test`
