# Schema changes to authored Resources must load-mutate-save, not reconstruct

Going forward, any schema migration to an authored `.tres` must load the existing resource, change only the field whose type moved, and save. Treat every authored asset as hand-tuned by default — there is no way to tell from the file itself that it isn't.
