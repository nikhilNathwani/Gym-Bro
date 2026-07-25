-- Migration: replace structured per-row cues (text/sort_order/level/is_header,
-- one row per bullet with individual remove buttons) with a single freeform
-- text block per exercise — easier to paste in/out of, and the user can type
-- their own hyphens/newlines/indentation for structure instead of the UI
-- imposing it.
--
-- Non-destructive: adds a new column and backfills it from the existing
-- `cues` table's rows, reconstructing the same bullet/indent text the old UI
-- rendered. The `cues` table itself is left in place (not dropped) so the
-- original structured data is still there if the flattening ever needs a
-- redo — drop it later once you're confident the new column has everything.

alter table exercises add column if not exists cues text;

update exercises e
set cues = sub.flattened
from (
  select
    exercise_id,
    string_agg(
      repeat('  ', level) ||
        case
          when is_header then text
          when level > 0 then '– ' || text
          else '• ' || text
        end,
      e'\n'
      order by sort_order
    ) as flattened
  from cues
  group by exercise_id
) sub
where sub.exercise_id = e.id;
