extends Node
## SaveSystem autoload: will write and read versioned saves; every save carries a
## version from the first one, new keys get defaults, renames get a migration and an
## old-save fixture (04_GUARDRAILS.md B7). Empty in Phase 0.
