# logseq-graph-ci
CI for logseq-db graph. Contributions welcome—hastily put together but works and tries to avoid accidental data loss.

Currently this does two checks:
* check that the graph validate (i.e that all the graph is correct) using the logseq CLI command.
* check that no more than three (3) (configurable) pages or blocks are removed between this commit and the last one, to prevent accidental deletion. This works but is not ideal, see [1].

The deletion guard runs `logseq validate` twice—once on this commit and once on the commit where CI last ran—and compares the page/block counts. The default threshold is 3 removals (`PAGE_DROP_THRESHOLD`/`BLOCK_DROP_THRESHOLD` envs). If the base graph file is missing, or the base commit cannot be found, the comparison is skipped. Net new pages/blocks can hide deletions, so this is only a stopgap until someone can build the better nbb-based approach.

If you never run CI, it means that you'll see little check-marks after all your pushes to github. Like this:

<img width="950" height="623" alt="Screenshot 2025-12-17 at 11 34 37 AM" src="https://github.com/user-attachments/assets/a1b0023e-c07d-410c-9364-2aca4032c68f" />
and you can configure notifications.


## How to use 
Take the yml file and put it into your graph github repository, inside folder `.github/workflows/`. If you want you may also take the script folder with it to do the check of graph deletion.

By default the workflow:
- installs the Logseq CLI and runs `logseq validate -g db.sqlite`
- runs `scripts/check-graph-counts.sh db.sqlite` to compare page/block counts against the previous CI run

To change thresholds, set env vars in the workflow step:
```
PAGE_DROP_THRESHOLD: 3
BLOCK_DROP_THRESHOLD: 3
```
The base commit defaults to the previous push (`github.event.before`) or PR base; override with `BASE_COMMIT`.

## Footnotes
[1] logseq dev cldwalker proposed something using an nbb-logseq script

> > me: Also is there a command to count datoms and pages without running the full validate ?

> cldwalker: This could be done with a couple lines of a nbb-logseq script. 
> cldwalker: https://github.com/logseq/logseq/blob/87dff14f4c82acfc83002a2c27585ce8eea6a0d7/deps/cli/src/logseq/cli/commands/validate.cljs#L24 opens a connection.
> cldwalker:  https://github.com/logseq/logseq/blob/87dff14f4c82acfc83002a2c27585ce8eea6a0d7/deps/db/src/logseq/db/frontend/validate.cljs#L125-L130 gets you the counts

If anyone wants to take that route, please submit a PR. The current script uses the first-line output from `logseq validate -g db.sqlite`, which looks like
```
  Read graph db.sqlite with counts: {:entities 24846, :pages 1471, :blocks 23037, :classes 61, :properties 105, :objects 3616, :property-pairs 30654, :datoms
  220018}
```
It extracts the page and block counts and compares them to the last CI run to catch deletions. If you create more than you delete, there is no warning, which is why a proper nbb-based action would be better. 
