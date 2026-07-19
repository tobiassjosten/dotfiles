# Finish legacy migration

> *Example file demonstrating a sequenced entry that landed at the front of the queue because it has to happen before everything else — delete or replace.*

The v3.2 schema migration introduced `users.user_id` and switched on dual-write alongside the deprecated `user_id_old`. The dual-write path and the old column still exist; the migration was paused before the drop step.

## Why this is `1-` (and why later entries had to be renumbered)

This is the kind of case `INDEX.md` describes under "Inserting a change before everything else": a paused-migration step whose completion now blocks downstream work. Several other planned changes assume `user_id_old` is gone — notably the event-bus payload format in `3-add-event-bus-EXAMPLE.md`. Until the old column is dropped, those changes would need compatibility shims, which would then have to be ripped out again. When this entry was added, the previously-numbered files were renamed (shifted up by one) to make room.

## Done when

- `user_id_old` is dropped from the `users` table in all environments.
- The dual-write code path is removed.
- The migration ticket is closed.
