# Recurring Tasks (Scheduler)

The `async-job-adapter-active_job` server can run a recurring scheduler alongside workers. It reads `config/recurring.yml`, parses cron expressions using Fugit, and enqueues Active Job tasks on schedule.

## Enable

By default, `bundle exec async-job-adapter-active_job-server` starts workers and the scheduler (if a schedule file is present). You can disable the scheduler with:

```bash
ASYNC_JOB_SKIP_RECURRING=true bundle exec async-job-adapter-active_job-server
# or compatible alias:
SOLID_QUEUE_SKIP_RECURRING=true bundle exec async-job-adapter-active_job-server
```

## Schedule file

Default path: `config/recurring.yml`.

Override via `ASYNC_JOB_RECURRING_SCHEDULE` (or `SOLID_QUEUE_RECURRING_SCHEDULE`).

Structure:

```yaml
production:
  my_task:
    class: MyJob          # or use `command: "SomeModule.some_method"`
    args: [ 42, { foo: "bar" } ]
    queue: default
    priority: 0
    schedule: "*/5 * * * *"   # Fugit/cron; also accepts "every 5 seconds"
```

Supported schedule strings:
- Cron (Fugit::Cron)
- Convenience phrases: "every N seconds/minutes/hours"

## Cross-host dedup & last run

- Dedup (ensures only one host enqueues per tick when multiple servers run):
  - Uses Redis if available (`REDIS_URL`) or `ASYNC_JOB_RECURRING_DEDUP=redis`.
  - Key: `<prefix>:recurring:exec:<task_key>:<run_at_epoch>` (NX + EX TTL).
  - TTL configurable via `ASYNC_JOB_RECURRING_DEDUP_TTL` (default 600 seconds).
- Last enqueued time:
  - Stores `<task_key> -> epoch` in `<prefix>:recurring:last` (Redis) when Redis is enabled.
  - Fallback is a no-op; apps may also record to Rails.cache if desired.
- Prefix:
  - `ASYNC_JOB_REDIS_PREFIX` (default `async-job`).

## Environment variables

- `ASYNC_JOB_RECURRING_SCHEDULE` — path to schedule file (default `config/recurring.yml`).
- `ASYNC_JOB_SKIP_RECURRING=true` — disable scheduler.
- `ASYNC_JOB_REDIS_PREFIX` — Redis key prefix (default `async-job`).
- `ASYNC_JOB_RECURRING_DEDUP=auto|redis|memory` — dedup backend (default `auto`: redis if `REDIS_URL`, else memory).
- `ASYNC_JOB_RECURRING_DEDUP_TTL` — dedup TTL in seconds (default `600`).
- `ASYNC_JOB_RECURRING_LAST=auto|redis|cache` — last run backend (currently redis or no-op; default `auto`).

## Logs

On start, the scheduler logs how many tasks were loaded and will print an enqueue message per tick. Errors while enqueuing are logged at warn level.

