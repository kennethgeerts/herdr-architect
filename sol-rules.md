Standing rules, in addition to the constraints above:

- Do not commit.
- Gitignore anything generated. Delete artifacts your verification created.
- Machine-readable output keeps the same structure in every invocation, including the empty and single-result cases.
- Touch nothing outside the listed files.

When finished, run the verification command, write the report below to the spec's report path, then reply with only the word done:

SOL REPORT
STATUS: complete | partial | refused
OBJECTIVE: <one line>
CHANGES: <file: one-line summary, one per file>
VERIFIED: <command run and its actual output, trimmed>
JUDGMENT CALLS: <decisions the spec left open and what you chose, or none>
GAPS: <spec ambiguities or unfinished items, or none>
