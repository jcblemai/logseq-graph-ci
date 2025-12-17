# logseq-graph-ci
CI for logseq-db graph. Please you are welcome to contribute, hastly done but works. 

Currently this does two checks:
* check that the graph validate (i.e that all the graph is correct) using the logseq CLI command.
* check that no more than three (3) (configurable number) pages or block are removed between this commit to the last, to prevent accidental deletion. This work but it not ideal at the moment, see [1].

If you never run CI, it means that you'll see little check-marks after all your pushes to github. Like this:

<img width="950" height="623" alt="Screenshot 2025-12-17 at 11 34 37 AM" src="https://github.com/user-attachments/assets/a1b0023e-c07d-410c-9364-2aca4032c68f" />
and you can configure notifications.
## How to use
Take the yml file and put it into your graph github repository, inside folder `.github/workflows/`. If you want you may also take the script folder with it to do the check of graph deletion

[1] logseq dev cldwalker proposed something using nbb-logseq script

> > me: Also is there a command to count datoms and pages without running the full validate ?

> cldwalker: This could be done with a couple lines of a nbb-logseq script. 
> cldwalker: https://github.com/logseq/logseq/blob/87dff14f4c82acfc83002a2c27585ce8eea6a0d7/deps/cli/src/logseq/cli/commands/validate.cljs#L24 opens a connection.
> cldwalker:  https://github.com/logseq/logseq/blob/87dff14f4c82acfc83002a2c27585ce8eea6a0d7/deps/db/src/logseq/db/frontend/validate.cljs#L125-L130 gets you the counts

If anyone wants to take that route, please submit a PR. The current script uses the output from the first line `logseq validate -g db.sqlite`, which looks like
```
  Read graph db.sqlite with counts: {:entities 24846, :pages 1471, :blocks 23037, :classes 61, :properties 105, :objects 3616, :property-pairs 30654, :datoms
  220018}
```
Extract the number of pages and blocks, and compare these with the one of the last CI run to see deletion (so it's not ideal in the sense that if you create more than you delete, there is no warning). 
