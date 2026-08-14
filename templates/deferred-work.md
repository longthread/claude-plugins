# Deferred work

> **Repo-wide; these rows outlive every programme.** Anything scoped to a single programme's
> lifetime belongs in that programme's `deferred.md` instead.

<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->

| item                                   | current behaviour                               | fix shape                                       | why deferred                                     | promoted from |
| -------------------------------------- | ----------------------------------------------- | ----------------------------------------------- | ------------------------------------------------ | ------------- |
| (example) webhook retry has no backoff | retries immediately on failure, in a tight loop | add exponential backoff with a max-attempts cap | affects every programme's webhooks, not just one | webhooks-v2   |
