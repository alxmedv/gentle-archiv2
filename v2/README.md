# Gentle Archiv2 — Table Archiving Framework
## Project L technical reference — Sections 1–4

**Source:** Updated `gentle-archiv2-main` ZIP archive, `v2/` directory  
**Scope:** Sections 1–4 of the proposed document: solution overview, framework architecture, archiving workflow, and SQL Server integration.

> **Evidence boundary:** This document describes the implementation visible in the supplied SQL scripts. It does not infer functionality that the scripts do not implement. In particular, the supplied workflow copies selected rows into an archive table; it does not delete those rows from the source table.

---

## 1. Solution overview

### 1.1 Purpose and operating model

`gentle-archiv2` is a configurable, stored-procedure-based framework for copying selected rows from a source table into a separately prepared archive table. It supports key-based selection, batch processing, continuation between runs, and either synchronous execution or asynchronous execution through SQL Server Agent worker jobs. Asynchronous runs can divide the worklist among multiple workers.

The framework separates generic orchestration from table-specific data movement:

- Generic procedures register and initialize a run, build a worklist of eligible keys, start processing, track progress, and support stopping and cleanup.
- A table-specific stored procedure performs the actual insert into the archive table.
- `ga_config` stores the table-specific configuration, while `ga_status` and `ga_log` record run state and execution messages.

The supplied example copies rows from `bricklink.dbo.Wanted` to `bricklink.dbo.ga_Wanted`, using `wantedID` as the key and `dbo.prga_Wanted` as the copy procedure.

### 1.2 Implemented capabilities

The supplied scripts implement the following sequence:

1. Register or validate a named archiving configuration.
2. Create a run record with a unique `job_id`.
3. Enumerate eligible source keys into a run-specific worklist.
4. Exclude keys already present in the archive target.
5. Optionally limit the number of selected rows and continue from a previously recorded key.
6. Process the worklist in configurable batches.
7. Execute the table-specific copy procedure inside a transaction for each batch.
8. Compare the procedure's reported insert count with the expected batch size; roll back and fail the run on a mismatch.
9. Track estimated and committed row counts and write progress/error messages.
10. Execute synchronously or create parallel SQL Server Agent worker jobs.
11. Stop runs and remove associated jobs, schedules, worklists and log records through the supplied management procedures.

### 1.3 Source-row removal belongs in the table-specific procedure

The framework delegates table-specific data movement to the configured `prga_` procedure. The intended implementation point for removing archived rows from the source table is the body of that procedure: after inserting the selected rows into the archive target, the procedure can delete the corresponding source rows.

The generic `populate_ga` procedure does not contain table-specific deletion logic. It invokes the configured `prga_` procedure inside the batch transaction and commits or rolls back that transaction based on the procedure's reported affected-row count. Therefore, source-row removal is designed to be implemented in the table-specific procedure, rather than as a separate generic framework step.

The supplied `dbo.prga_Wanted` example currently demonstrates the insert into `bricklink.dbo.ga_Wanted`; it does not itself contain the corresponding source-table `DELETE`. Thus, the extension point is part of the framework design, while source deletion is not yet implemented in this example. For a complete move-and-purge operation, the table-specific procedure should perform the archive insert and source deletion as one transactionally consistent batch, and report the count expected by the generic worker.

### 1.4 Main implementation components

| Component | Responsibility |
|---|---|
| `invoke_ga` | Entry point; registers/validates configuration, creates the run record and calls worklist construction |
| `build_jobindex` | Dynamically creates the run-specific table of eligible source keys and their ordered row numbers |
| `create_ga_job` | Starts an initialized run synchronously or delegates to asynchronous job creation |
| `create_ga_job_async` | Creates SQL Server Agent worker jobs and a shared one-time schedule |
| `populate_ga` | Loads a worker's portion of the worklist and copies rows in batches |
| `stop_ga` | Marks runs stopped and optionally stops/deletes worker jobs and related artefacts |
| `cleanup_ga` | Removes worker jobs, schedules, worklist tables and log records; supports orphan cleanup |
| `adjust_agent_job` | Adjusts a recurring SQL Server Agent schedule interval based on the latest run information |
| `prga_Wanted` | Example table-specific procedure for table-specific archiving; the procedure body is the intended location for both archive insertion and corresponding source-row deletion |
| `ga_config` | Persistent job configuration |
| `ga_status` | Run-level state, parameters and row-count tracking |
| `ga_log` | Execution messages and batch progress |
| `gaBatchKeyType` | Table-valued parameter type used to pass a batch of keys to the copy procedure |

---

## 2. Framework architecture

### 2.1 Logical architecture

The framework objects are installed in the `DBA` database. The example source and archive tables are in the `bricklink` database. SQL Server Agent jobs and schedules are managed through `msdb`.

```text
                         SQL Server Agent
                                |
                                v
                           invoke_ga
                                |
                +---------------+----------------+
                |                                |
                v                                v
             ga_config                        ga_status
                |                         run ID, state,
                |                         parameters, counts
                |
                v
                         build_jobindex
                                |
                  enumerate eligible source keys
                  + filter / row limit / continuation
                  + exclude keys already in target
                                |
                                v
                    ga_jobindex_<job_id>
                     (rowkey, rownum)
                                |
                                v
                          create_ga_job
                         /              \
                synchronous          asynchronous
                    |                     |
                    |              create_ga_job_async
                    |                     |
                    |              SQL Agent worker jobs
                    |                     |
                    +----------+----------+
                               |
                               v
                          populate_ga
                               |
                     worker-specific key subset
                       (rownum modulo degree)
                               |
                         batch key set
                       gaBatchKeyType
                               |
                               v
                    Table-specific copy procedure
                         (e.g. prga_Wanted)
                               |
                     SELECT source / INSERT target
                               |
                       transaction + rowcount
                           validation
                               |
                         ga_status / ga_log

Management: stop_ga, cleanup_ga
Recurring example wrapper: job_ga_Wanted_x2 -> adjust_agent_job
```

The table-specific procedure owns table-specific data movement. The intended design is for it to insert the selected rows into the target and then delete those same rows from the source within the batch transaction. The current `prga_Wanted` example implements the insert but not yet the delete.

### 2.2 Framework metadata

The scripts create the following framework objects in `DBA` if they do not already exist.

**`ga_config` — persistent configuration**

The table contains:

- `job_name`: unique logical name for the archiving configuration.
- `job_proc`: table-specific stored procedure.
- `src_tbname`: source table name.
- `src_keycol`: source key column.
- `trg_tbname`: archive target table.
- `whereand`: filter expression used during key enumeration.
- `comm_rows`: batch size.

On first invocation, `invoke_ga` inserts the configuration. On later invocations with the same job name, it compares the filter expression (using a SHA2-256 hash), procedure, source table, key column and target table. A mismatch raises a configuration error. The batch size is stored on initial registration; the comparison shown in the script does not include `comm_rows`.

**`ga_status` — run state**

The table records:

- `job_id`, `job_name`, `start_time` and `end_time`.
- `parallel_degree` and `job_async`.
- `whereand`, `requested_rows` and `estimated_rows`.
- `committed_rows`.
- `cont_job` and `last_keyid`.
- `status_desc`.

The scripts use statuses including `init`, `run`, `completed`, `stopped`, `failed` and `failed init`. Cleanup marks a retained status row by appending `(x)` to its status text.

**`ga_log` — execution log**

The table stores a log identity, run identifier, timestamp, job name, message and optional worker parameter. `populate_ga` records worker-level estimated counts, committed batches, completion and errors. Cleanup deletes log records for the selected run.

**`gaBatchKeyType` — batch key parameter**

The table type contains a `rowkey bigint` column. It is passed as a read-only table-valued parameter to the table-specific procedure.

### 2.3 Worklist and parallel worker model

`build_jobindex` creates a physical table named:

`ga_jobindex_<job_id>`

The worklist contains:

- `rowkey`: the selected source key.
- `rownum`: `ROW_NUMBER()` ordered by the key ascending.

The worklist is the run-specific queue consumed by `populate_ga`. Each worker loads its selected rows into a local temporary table, `#jobkeys`, whose `rowkey` is also `bigint`.

For asynchronous execution, `create_ga_job_async` creates one SQL Server Agent job per worker. Names follow:

`job_<job_id>.<thread_number>`

The jobs share a one-time schedule whose start time is set approximately ten seconds in the future. Each worker invokes `populate_ga` with its thread number. Work is partitioned using:

`rownum % parallel_degree = thread_number`

The worker thread numbers run from zero to `parallel_degree - 1`. A zero parallel degree is normalized to one in `create_ga_job_async`.

### 2.4 Generic orchestration versus table-specific logic

The generic procedures handle configuration, key enumeration, work allocation, batching, status and logging. They do not define the source/target column mapping.

That mapping is implemented in a table-specific stored procedure such as `dbo.prga_Wanted`. It accepts:

- `@parkeys`: `gaBatchKeyType READONLY`, containing the current batch of source keys.
- `@rows_affected`: output parameter reporting the number of rows inserted.

This design allows the orchestration framework to be reused for other tables, provided a compatible target table and a corresponding table-specific `prga_` procedure are prepared. That procedure is also the intended place to implement source-row deletion, so table-specific copy and purge operations remain together within the generic worker's batch transaction.

---

## 3. Archiving workflow

### 3.1 Initialization and configuration

The entry point is `dbo.invoke_ga`, executed in the `DBA` database. Its parameters include:

- Required source table (`@pTableName`) and key column (`@pKeyCol`).
- Optional job name (`@pJobName`).
- Optional table-specific procedure (`@pJobProc`).
- Optional archive target (`@pTrgTableName`).
- Optional filter expression (`@pWhereAnd`).
- Optional maximum number of rows (`@pNbOfRowsToMove`).
- Batch size (`@pCommRows`).
- Continuation flag (`@pContJob`).
- Parallel degree (`@degree`), asynchronous flag (`@async`) and silent-output flag (`@silent`).

Defaults in the script are:

- Job name: `ga_<source-table-name>`.
- Target table: source table name replaced with `ga_<source-table-name>`.
- Copy procedure: `pr<job-name>`.
- Batch size: 1,000 rows.
- Continuation, asynchronous execution and silent mode: disabled.
- Parallel degree: zero.

`invoke_ga` first looks for an existing non-terminal run with the same job name and filter hash. If one exists, it reports that the job exists rather than creating another run. Otherwise, it creates or validates the `ga_config` entry, optionally retrieves a previous continuation key, generates a new `job_id`, and inserts an `init` row in `ga_status`.

It checks that the configured target table and copy procedure exist, then calls `build_jobindex`. The estimated worklist row count is written to `ga_status.estimated_rows`.

### 3.2 Worklist construction and selection rules

`build_jobindex` constructs dynamic SQL to create the run-specific worklist. The selection logic:

- Reads the source table and key column.
- Applies the supplied filter expression.
- Applies `TOP (<requested row count>)` when a positive limit is supplied.
- If a continuation key is supplied, includes only keys greater than that key.
- Excludes keys already present in the archive target using `NOT EXISTS`.
- Assigns `rownum` in ascending key order.
- Uses `WITH (NOLOCK)` on the source-table enumeration.

The worklist table is created using `SELECT ... INTO`. The row count returned by the dynamic statement is captured as the estimated count for the run.

Continuation is based on the `last_keyid` stored on a prior run with `cont_job = 1` and a terminal status (`failed`, `completed` or `stopped`). The next worklist is then restricted to keys greater than that value, in addition to the target anti-join.

### 3.3 Execution modes

`create_ga_job` selects an initialized run by job name. It refuses to start when no initialized run is found, the estimated count is zero, or a positive parallel degree is requested without asynchronous execution.

- **Synchronous:** calls `populate_ga` directly.
- **Asynchronous:** calls `create_ga_job_async`, which creates the SQL Server Agent worker jobs.

For asynchronous runs, `create_ga_job_async` creates a shared one-time schedule starting approximately ten seconds in the future and attaches it to each worker job. Each worker calls `populate_ga` with its thread number.

The updated `test_v2.sql` continues to demonstrate a run of up to ten million rows with continuation enabled, parallel degree eight and asynchronous execution.

### 3.4 Batch processing

`populate_ga` identifies the run and its configuration, marks the run as `run`, and loads the appropriate worklist keys into `#jobkeys`. For a parallel run with a thread number, it filters the worklist using the modulo partition described in Section 2.3.

The procedure processes keys in ascending order, in batches sized by `ga_config.comm_rows` (defaulting to 1,000 if null). For each batch it:

1. Populates the `gaBatchKeyType` table-valued parameter with the next keys.
2. Starts a transaction.
3. Calls the configured table-specific copy procedure through `sp_executesql`.
4. Receives the procedure's `@rows_affected` output value.
5. Compares that value with the number of keys in the batch.
6. Throws an error if the counts differ; the catch block rolls back the open transaction and marks the run failed.
7. Commits a matching batch.
8. Writes the committed count and last key to `ga_log`.
9. Increments `ga_status.committed_rows`.

The loop checks the run status between batches and exits if the status is `stopped`. When the committed count equals the estimated count, the run is marked `completed`, the end time is set, and `last_keyid` is recorded.

The current `populate_ga` script sets `@debug = 1`. As written, it emits diagnostic result sets containing run/configuration details, the generated worklist query and per-batch row counts. This is observable behavior of the supplied version.

### 3.5 Stop, failure and cleanup

`populate_ga` uses `TRY/CATCH`. If a batch fails, it rolls back an open transaction, logs the error and last key, and marks the run `failed`.

`stop_ga` marks matching runs as `stopped`. With `@force = 1`, it checks the corresponding SQL Server Agent worker jobs and calls `sp_stop_job` for jobs reported as in progress. With `@cleanup = 1`, it can delete worker jobs and schedules, delete the run's log entries and append `(x)` to the status.

`cleanup_ga` supports selection by job name, job ID or status. It deletes associated worker jobs and schedules, drops the run's worklist table, deletes its log entries and appends `(x)` to the status. Its `orphaned` mode deletes log records without a corresponding status row and drops worklist tables whose run identifier is not present in `ga_status`.

### 3.6 Recurring SQL Agent job wrapper

The updated repository includes `job_ga_Wanted_x2.sql`, which defines a recurring SQL Server Agent job with three steps:

1. **Initialize:** calls `invoke_ga` for `ga_Wanted_x2`, targeting `bricklink.dbo.Wanted` and `wantedID`, with a ten-million-row limit, continuation enabled, parallel degree eight and asynchronous execution.
2. **Cleanup and start:** cleans up completed and failed runs, then calls `create_ga_job` to start the initialized run.
3. **Adjust schedule:** calls `adjust_agent_job` using the SQL Agent job name.

The supplied job script configures an initial daily schedule with a subday interval of 60 minutes. `adjust_agent_job` derives a new interval from the duration of the most recent completed/stopped run (or 60 minutes when its estimated plus committed count is zero), and updates the schedule when the difference from the current interval is greater than one minute.

This recurring wrapper is an example deployment configuration, not a mandatory part of the generic framework.

### 3.7 Workflow summary

```text
invoke_ga
   |
   +-- find active run / validate or register ga_config
   |
   +-- create ga_status run record
   |
   +-- build_jobindex
   |      |
   |      +-- apply filter and optional TOP limit
   |      +-- apply continuation key, if any
   |      +-- exclude keys already in target
   |      +-- create ga_jobindex_<job_id>
   |
   v
create_ga_job
   |
   +-- synchronous ----------------------+
   |                                     |
   +-- asynchronous                      |
          |                              |
          v                              |
   create_ga_job_async                   |
          |                              |
          v                              |
   SQL Agent worker jobs                 |
          |                              |
          +---------------+--------------+
                          |
                          v
                     populate_ga
                          |
                  select worker key set
                          |
                    batch key set
                          |
                          v
               table-specific copy procedure
                          |
                  INSERT into archive table
                          |
                  validate inserted count
                          |
                    COMMIT / log progress
                          |
                   repeat until complete
                          |
             completed / failed / stopped
                          |
                          v
                  cleanup_ga (as required)
```

---

## 4. SQL Server integration

### 4.1 Database and SQL Server components

The supplied scripts assume:

- **`DBA`:** framework database containing `ga_config`, `ga_status`, `ga_log`, `gaBatchKeyType` and the generic procedures.
- **Application database (`bricklink` in the example):** contains the source and archive tables and is accessed by the table-specific copy procedure.
- **`msdb`:** stores SQL Server Agent jobs and schedules used by asynchronous execution and the recurring example job.
- **SQL Server Agent:** required for asynchronous worker execution and the supplied scheduled wrapper.

The scripts use SQL Server features including table-valued parameters, dynamic SQL (`sp_executesql`), `TRY/CATCH`, `THROW`, `IDENTITY_INSERT`, `ROW_NUMBER()`, and SQL Server Agent stored procedures.

### 4.2 Table-specific integration: `Wanted` example

`dbo.prga_Wanted` copies rows from `bricklink.dbo.Wanted` to `bricklink.dbo.ga_Wanted`. It selects rows whose `wantedID` appears in `@parkeys`, explicitly maps the listed source columns to the target columns, and enables `IDENTITY_INSERT` so that the original `wantedID` values can be inserted.

The procedure assigns `@@ROWCOUNT` to `@rows_affected` and then disables `IDENTITY_INSERT`. The target table must already exist. The script contains commented examples for creating an empty target table with `SELECT ... INTO` and creating an index on `wantedID`; these are not executed by the framework.

The generic framework checks that the target table and copy procedure exist. It does not create the target table or validate its complete schema, indexes, constraints, triggers, identity definition or permissions.

### 4.3 Example invocation

The updated `test_v2.sql` demonstrates:

```sql
EXEC dbo.invoke_ga
    @job_name = 'ga_Wanted_x2',
    @job_proc = 'prga_Wanted',
    @pTableName = 'bricklink.dbo.Wanted',
    @pKeyCol = 'wantedID',
    @pNbOfRowsToMove = 10000000,
    @pContJob = 1,
    @degree = 8,
    @async = 1;

EXEC dbo.create_ga_job 'ga_Wanted_x2';
```

The first call initializes the run and builds its worklist. The second starts it. The test script also demonstrates calls to `stop_ga` and `cleanup_ga`, plus queries against `ga_config`, `ga_status` and `ga_log`.

The updated `job_ga_Wanted_x2.sql` provides a recurring SQL Agent wrapper. Its schedule is configured for a 60-minute subday interval, and its third step invokes `adjust_agent_job` to adapt that interval based on the latest run information.

### 4.4 Integration pattern for another table

The implementation pattern evidenced by the `Wanted` example is:

1. Prepare the archive target table with a compatible schema.
2. Identify a stable source key column.
3. Create a table-specific procedure accepting `gaBatchKeyType READONLY` and an output `bigint` row count.
4. Implement the source-to-target column mapping and insert logic in that procedure.
5. Register and initialize the job using `invoke_ga`, supplying the source table, key, target table, procedure, filter and execution options.
6. Start the initialized run using `create_ga_job`.

The copy procedure must report the number of rows it inserted. The generic worker compares this value with the batch key count and fails the batch if they differ.

### 4.5 Source-level observations from the updated scripts

The following observations are based on the current ZIP contents:

- **The previous `int`/`bigint` inconsistency is no longer present in the worker worklist.** `gaBatchKeyType.rowkey` and `#jobkeys.rowkey` are both `bigint` in the updated scripts.
- **Dynamic SQL inputs require control.** `build_jobindex` concatenates the source table name, target table name, key-column name and filter expression into a dynamic statement. The scripts do not show comprehensive identifier quoting or parameterization for these inputs. They should be treated as trusted configuration and validated before production use.
- **`NOLOCK` is used during key enumeration and in the sample copy procedure.** The scripts therefore do not demonstrate a snapshot-consistent selection and copy process under concurrent source-table modifications.
- **Continuation records a worker-local last key in a parallel run.** Each `populate_ga` worker maintains its own `@lastMaxKey`; when the shared run reaches completion, the worker that performs the final status update writes its local value to `ga_status.last_keyid`. The scripts do not show a separate calculation of the global maximum key across all workers. This should be reviewed before relying on continuation after a parallel run.
- **The row-count check is a batch-level control, not full reconciliation.** It detects a difference between the batch key count and the copy procedure's reported insert count. The scripts do not provide a separate source/target reconciliation process.
- **`populate_ga` currently has `@debug = 1`.** Diagnostic `SELECT` statements are therefore active and can produce result sets during execution.
- **Target provisioning and schema validation are external responsibilities.** The framework checks object existence but does not provision or comprehensively compare source and target metadata.
- **Source deletion is a table-specific responsibility by design.** It is intended to be implemented in the body of the configured `prga_` procedure, following the archive insert and within the same batch transaction. The supplied `prga_Wanted` example currently demonstrates only the insert, so its source-row deletion still needs to be added. Archive retention, restoration and end-to-end recovery are also not implemented in the supplied scripts.

These points identify behavior and review items in the supplied version; they do not establish that the framework cannot be extended.

---

**Scope note:** Sections 5 onward—operational management in greater depth, recovery/restoration, performance assessment, security/retention and BrickLink-specific recommendations—are intentionally excluded, as requested.
