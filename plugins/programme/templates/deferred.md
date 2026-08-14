# <PROGRAMME_NAME> — deferred work

> **Scoped to this programme; these rows die with it.** Anything that outlives it belongs in the
> repo-wide `deferred-work.md`.
>
> **This programme cannot be closed while a row here is still open.** Each must be promoted to that
> file or killed with a reason recorded in the archive — otherwise a still-relevant item is archived
> alive.

<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->

| item                                   | current behaviour                               | fix shape                                       | why deferred                                        |
| -------------------------------------- | ----------------------------------------------- | ----------------------------------------------- | --------------------------------------------------- |
| (example) webhook retry has no backoff | retries immediately on failure, in a tight loop | add exponential backoff with a max-attempts cap | lower priority than this phase's terminal condition |
