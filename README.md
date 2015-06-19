sqlcached
==============

Sqlcached is a Node.js HTTP server that provides a REST interface to run
queries on a MySQL database, and to cache the results.


## Introduction

The main concept in Sqlcached is the **query template**: a SQL query with
some named parameters. For example

```sql
SELECT * FROM users WHERE username = '{{ username }}' OR email = '{{ email }}'
```
it's a query template with two parameters: *username* and *email*.

Each query template can be interpolated with some data, to produce a
SQL query that is runnable on the database server.

When a client asks the service to run the template *T* providing some actual
parameters *D*, Redis is inquired as the first step, so if the results
related to *(T, D)* are found, they're immediately returned.
If no data is available from Redis, a SQL query is generated and executed on
MySQL. The results are then stored in Redis for any subsequent request,
and returned to the client.

Every query result is cached in Redis until it's explicitly cleared via the
API (see below) or, if a cache timeout was provided, the cache is automatically
cleared when the timeout expires.


## API

### Query templates
#### GET /queries
Returns the set of all the query templates available.

#### POST /queries
Creates a new query template. Example payload
```json
{
  "id": "foo",
  "query_template": "SELECT * FROM users WHERE username = '{{ uname }}'",
  "cache": 300
}
```
The key `cache` is optional, it sets a timeout in seconds for the cached data.
When the query template is executed with actual parameters, the query result
is kept in the cache for no longer than the specified amount of seconds.

#### DELETE /queries/:id
Deletes the query template with the specified `id`, and clears any related
query result.

### Query results (database data)
A query result is obtained by running on the database a template filled with
some actual parameters.

#### GET /data/:query_id?query_params[foo]=bar&query_params[baz]=biz
Runs the template identified by *query_id*, interpolating the parameter *foo*
with the value *bar* and the parameter *baz* with the value *biz*.

#### DELETE /data/:query_id/cache
Clears any query result related to the query template `query_id`.

#### DELETE /data/:query_id/cache?query_params[foo]=bar&query_params[baz]=biz
Clears any query result related to the pair *(query_id, D)*; where *D* is the
set *{(foo, bar), (baz, biz)}*.

#### POST /data-batch
It's the same as (POST /queries) + (GET /data/:query_id). It creates a query
template if it doesn't exist, and executes it with the provided parameters.
```json
{
  "batch": [
    {
      "query_id": "user",
      "query_template": "SELECT * FROM users WHERE id IN ( {{ user_ids }} )",
      "query_params": {
        "user_ids": "1, 2, 3"
      }
    }
  ]
}
```

It is possible to provide multiple and/or nested pairs
*(query_template, parameters)*, for example
```json
{
  "batch": [
    [
      [
        {
          "query_id": "user",
          "query_template": "SELECT * FROM users WHERE id = {{ id }}",
          "query_params": {
            "id": 8661209
          }
        },
        {
          "query_id": "translation",
          "query_template": "SELECT * FROM translations WHERE translateable_id = {{ translateable_id }} AND translateable_type = '{{ translateable_type }}'",
          "query_params": {
            "translateable_id": 80903235,
            "translateable_type": "Product"
          }
        },
        {
          "query_id": "shop",
          "query_template": "SELECT * FROM shops WHERE user_id = {{ user_id }}",
          "query_params": {
            "user_id": 8661209
          }
        }
      ]
    ]
  ]
}
```

## Usage

### Compile
`npm install && npm run compile`

### Run
Configure your database in `config/database.yml` and your Redis instance in
`config/redis.yml`.
The MySQL connection pool can be created using different combinations of
hosts and users, and each instance contributes to the pool with
`connectionLimit` connections.

Start the server with `node index.js`.

The server runs on port `8081` by default, eventually you can override that
value with the option `--port`.

### Run the specs
`npm install && npm run test`
