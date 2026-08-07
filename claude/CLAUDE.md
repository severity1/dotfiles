## Tool Preferences

*Which CLI tool to use when you shell out. All of these are installed.*
- **Built-in Tools First**: Use the Read, Grep, and Glob tools before Bash. Shell out only when no built-in tool fits
- **File Search**: Use `fd` instead of `find`. It is faster and it respects .gitignore
- **Text Search**: Use `rg` instead of `grep`. It is faster and it respects .gitignore
- **Code Structure Search**: Use `ast-grep` to match code patterns such as classes, functions, and interfaces. Call it as `ast-grep`, not `sg`
- **Data Processing**: Use `jq` for JSON. Use `yq` for YAML and XML
- **Text Processing**: Use `sed` to edit streams. Use `awk` to scan patterns
- **Cloud Platforms**: Use the `aws` CLI for AWS
- **Infrastructure**: Use `terraform` to provision. Use `terraform-docs` to generate module docs


## Code Standards

*Universal principles for writing quality code*
- **KISS**: Keep It Simple. Favor simple, maintainable solutions over clever code
- **YAGNI**: You Ain't Gonna Need It. Don't implement features or abstractions until actually needed
- **DRY**: Don't Repeat Yourself. Extract repeated logic into utility functions
- **Naming**: Use descriptive, self-documenting names. Prefer clarity over brevity (getUserById vs getUsr)
- **Function Size**: Keep functions small and focused on a single task. Split if doing multiple things
- **Fail Fast**: Validate inputs early and fail immediately with clear errors. Don't let invalid data propagate
- **Security**: Never log/commit secrets, validate all inputs, redact sensitive data in logs
- **Imports**: Group (stdlib → third-party → local), sort alphabetically within groups
- **Error Handling**: Handle errors gracefully with meaningful, actionable messages
- **Comments**: Explain "why" decisions were made, not "what" the code does
- **Testing**: Add tests following existing project patterns before marking work complete
- **Changes**: Make minimal, focused changes that solve one problem at a time


## Communication Style

*Preferences for how you talk to me, and for code, comments, and documentation*

### ASD-STE100 (the specification)

Write in Simplified Technical English. This covers chat replies, plan and summary text, code comments, docs, commit messages, and PR descriptions.

Apply the 53 writing rules. Do **not** apply the dictionary of about 900 approved words: it rejects roughly 1,200 common words, which is correct for a maintenance manual and wrong for technical discussion. Apply the word counts to documentation. In chat, keep the same discipline without counting words.

- **Sentence Length**: A procedural sentence has 20 words at most. A descriptive sentence has 25 words at most
- **One Instruction Per Sentence**: One topic per paragraph, six sentences per paragraph at most
- **Verb Forms**: Use the infinitive, the imperative, the simple present, the simple past, the simple future, and the past participle as an adjective. Do not stack auxiliary verbs. The present perfect is not permitted: write "We received the report", not "We have received the report"
- **The "-ing" Form**: Use it only as a technical noun, or as a modifier inside a technical noun
- **Active Voice**: Write "The script reads the config file", not "The config file is read by the script". Use the passive voice only in descriptive text, and only when the agent is unknown
- **Noun Clusters**: Three words at most. "Backup task log file" has four, so write "the log file for the backup task"
- **Keep Sentence Parts**: Do not drop the verb, the subject, or an article to make a sentence shorter. A shorter sentence that loses a part becomes ambiguous
- **One Word, One Meaning**: Explain the same thing the same way. Do not reach for a synonym to add variety
- **Approved Word Pairs**: Prefer "make sure" over "ensure/verify/check/confirm", "start" over "initiate/commence", "use" over "utilize"

Source: <https://www.asd-ste100.org> (Issue 9, 15 January 2025, free to download).

### House rules (NOT ASD-STE100)

These are mine. Do not cite the specification as their source.

- **No Emojis**: Never use emojis in code, comments, commit messages, or documentation
- **No Em or En Dashes**: Never build a sentence with an em dash (—) or an en dash (–). Use a period, a comma, a colon, or parentheses instead. A plain hyphen (-) is fine in compound words and flags
- **Plain English, Not Academic**: Write as if English is your second language. Use short, common words and simple sentence patterns. No academic tone, no rhetorical flourish, no long subordinate clauses. Say the thing in the most direct way
- **Clarity**: Write in clear, direct language without unnecessary embellishment
- **Review First**: When asked to review or analyze something, do that first and report findings before making any changes
- **Humble Language**: Avoid claiming "success" without verification. Only use "successfully" when tests prove it
  - Bad: "Successfully implemented feature X, ready for testing"
  - Good: "Implemented feature X, ready for testing"
  - Good: "Ran tests for feature X, they all completed successfully"