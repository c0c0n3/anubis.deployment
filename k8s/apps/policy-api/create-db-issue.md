Create DB issue
---------------

It looks like Anubis can't create its own DB named "anubis" in Postgres.
At least not in our current deployment which basically mirrors that of
the official Docker Compose test bed:
- https://github.com/orchestracities/anubis/blob/master/docker-compose.yaml

On startup Anubis runs the SQL Alchemy scripts but they fail because
the DB isn't there. So Anubis crashes. This happens at least with
these two Postgres images:
* `timescale/timescaledb-postgis:2.3.0-pg13`
* `postgres:14`


### Workaround

Create the DB beforehand.

```bash
$ kubectl exec -it svc/postgres -- sh
% psql -U postgres
postgres=# CREATE DATABASE anubis OWNER postgres ENCODING 'UTF8';
```

### Error logs

```bash
$ kubectl logs svc/postgres
...
2022-10-25 16:48:02.081 UTC [1] LOG:  database system is ready to accept connections
2022-10-25 16:50:35.728 UTC [69] FATAL:  database "anubis" does not exist
2022-10-25 17:06:18.587 UTC [86] FATAL:  database "anubis" does not exist
```

```bash
$ kubectl logs svc/policy-api -c policy-api
time=2022-10-25T17:06:16.311Z  | lvl=INFO:     | comp=uvicorn.error | msg="Will watch for changes in these directories: ['/home/apiuser/anubis-management-api']
time=2022-10-25T17:06:16.312Z  | lvl=INFO:     | comp=uvicorn.error | msg="Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
time=2022-10-25T17:06:16.312Z  | lvl=INFO:     | comp=uvicorn.error | msg="Started reloader process [1] using StatReload
time=2022-10-25T17:06:18.518Z  | lvl=INFO:     | comp=uvicorn.error | msg="Started server process [7]
time=2022-10-25T17:06:18.519Z  | lvl=INFO:     | comp=uvicorn.error | msg="Waiting for application startup.
time=2022-10-25T17:06:18.600Z  | lvl=ERROR:    | comp=uvicorn.error | msg="Traceback (most recent call last):
  File "/.venv/lib/python3.9/site-packages/pg8000/legacy.py", line 444, in __init__
    super().__init__(*args, **kwargs)
  File "/.venv/lib/python3.9/site-packages/pg8000/core.py", line 362, in __init__
    raise e
  File "/.venv/lib/python3.9/site-packages/pg8000/core.py", line 358, in __init__
    raise context.error
pg8000.exceptions.DatabaseError: {'S': 'FATAL', 'V': 'FATAL', 'C': '3D000', 'M': 'database "anubis" does not exist', 'F': 'postinit.c', 'L': '885', 'R': 'InitPostgres'}

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3361, in _wrap_pool_connect
    return fn()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 320, in connect
    return _ConnectionFairy._checkout(self)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 884, in _checkout
    fairy = _ConnectionRecord.checkout(pool)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 486, in checkout
    rec = pool._do_get()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/impl.py", line 146, in _do_get
    self._dec_overflow()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/langhelpers.py", line 70, in __exit__
    compat.raise_(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/compat.py", line 208, in raise_
    raise exception
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/impl.py", line 143, in _do_get
    return self._create_connection()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 266, in _create_connection
    return _ConnectionRecord(self)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 381, in __init__
    self.__connect()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 678, in __connect
    pool.logger.debug("Error on connect(): %s", e)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/langhelpers.py", line 70, in __exit__
    compat.raise_(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/compat.py", line 208, in raise_
    raise exception
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 673, in __connect
    self.dbapi_connection = connection = pool._invoke_creator(self)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/create.py", line 578, in connect
    return dialect.connect(*cargs, **cparams)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/default.py", line 598, in connect
    return self.dbapi.connect(*cargs, **cparams)
  File "/.venv/lib/python3.9/site-packages/pg8000/__init__.py", line 111, in connect
    return Connection(
  File "/.venv/lib/python3.9/site-packages/pg8000/legacy.py", line 457, in __init__
    raise cls(msg)
pg8000.dbapi.ProgrammingError: {'S': 'FATAL', 'V': 'FATAL', 'C': '3D000', 'M': 'database "anubis" does not exist', 'F': 'postinit.c', 'L': '885', 'R': 'InitPostgres'}

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "/.venv/lib/python3.9/site-packages/starlette/routing.py", line 635, in lifespan
    async with self.lifespan_context(app):
  File "/.venv/lib/python3.9/site-packages/starlette/routing.py", line 530, in __aenter__
    await self._router.startup()
  File "/.venv/lib/python3.9/site-packages/starlette/routing.py", line 614, in startup
    handler()
  File "/home/apiuser/anubis-management-api/./anubis/main.py", line 78, in on_startup
    p_models.init_db()
  File "/home/apiuser/anubis-management-api/./anubis/policies/models.py", line 67, in init_db
    Base.metadata.create_all(bind=autocommit_engine)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/sql/schema.py", line 4917, in create_all
    bind._run_ddl_visitor(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3227, in _run_ddl_visitor
    with self.begin() as conn:
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3143, in begin
    conn = self.connect(close_with_result=close_with_result)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3315, in connect
    return self._connection_cls(self, close_with_result=close_with_result)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 96, in __init__
    else engine.raw_connection()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3394, in raw_connection
    return self._wrap_pool_connect(self.pool.connect, _connection)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3364, in _wrap_pool_connect
    Connection._handle_dbapi_exception_noconnection(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 2198, in _handle_dbapi_exception_noconnection
    util.raise_(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/compat.py", line 208, in raise_
    raise exception
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/base.py", line 3361, in _wrap_pool_connect
    return fn()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 320, in connect
    return _ConnectionFairy._checkout(self)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 884, in _checkout
    fairy = _ConnectionRecord.checkout(pool)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 486, in checkout
    rec = pool._do_get()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/impl.py", line 146, in _do_get
    self._dec_overflow()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/langhelpers.py", line 70, in __exit__
    compat.raise_(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/compat.py", line 208, in raise_
    raise exception
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/impl.py", line 143, in _do_get
    return self._create_connection()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 266, in _create_connection
    return _ConnectionRecord(self)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 381, in __init__
    self.__connect()
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 678, in __connect
    pool.logger.debug("Error on connect(): %s", e)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/langhelpers.py", line 70, in __exit__
    compat.raise_(
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/util/compat.py", line 208, in raise_
    raise exception
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/pool/base.py", line 673, in __connect
    self.dbapi_connection = connection = pool._invoke_creator(self)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/create.py", line 578, in connect
    return dialect.connect(*cargs, **cparams)
  File "/.venv/lib/python3.9/site-packages/sqlalchemy/engine/default.py", line 598, in connect
    return self.dbapi.connect(*cargs, **cparams)
  File "/.venv/lib/python3.9/site-packages/pg8000/__init__.py", line 111, in connect
    return Connection(
  File "/.venv/lib/python3.9/site-packages/pg8000/legacy.py", line 457, in __init__
    raise cls(msg)
sqlalchemy.exc.ProgrammingError: (pg8000.dbapi.ProgrammingError) {'S': 'FATAL', 'V': 'FATAL', 'C': '3D000', 'M': 'database "anubis" does not exist', 'F': 'postinit.c', 'L': '885', 'R': 'InitPostgres'}
(Background on this error at: https://sqlalche.me/e/14/f405)

time=2022-10-25T17:06:18.601Z  | lvl=ERROR:    | comp=uvicorn.error | msg="Application startup failed. Exiting.
```
