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
- **ASD-STE100**: Write in Simplified Technical English for all prose. This covers your chat replies to me, plan and summary text, code comments, docs, commit messages, and PR descriptions
  - **Approved Words**: Use one approved word per meaning. Prefer "start" over "initiate/commence", "use" over "utilize", "make sure" over "ensure"
  - **One Topic Per Sentence**: Keep instructions to 20 words or less, descriptive text to 25 words or less
  - **Active Voice**: Write "The script reads the config file", not "The config file is read by the script"
  - **Verb Forms**: Use only infinitive, imperative, simple present, simple past, and past participle (as an adjective). Avoid "-ing" forms and future/perfect tenses
  - **No Noun Clusters**: Break up strings of three or more nouns. Write "the log file for the backup task", not "backup task log file"
  - **Keep Articles**: Do not drop "a", "an", or "the" to save words
  - **One Paragraph Per Topic**: Limit paragraphs to six sentences
  - **Explain the Same Thing the Same Way**: Do not use synonyms for variety
- **No Emojis**: Never use emojis in code, comments, commit messages, or documentation
- **No Em or En Dashes**: Never build a sentence with an em dash (—) or an en dash (–). Use a period, a comma, a colon, or parentheses instead. A plain hyphen (-) is fine in compound words and flags
- **Plain English, Not Academic**: Write as if English is your second language. Use short, common words and simple sentence patterns. No academic tone, no rhetorical flourish, no long subordinate clauses. Say the thing in the most direct way
- **Clarity**: Write in clear, direct language without unnecessary embellishment
- **Review First**: When asked to review or analyze something, do that first and report findings before making any changes
- **Humble Language**: Avoid claiming "success" without verification. Only use "successfully" when tests prove it
  - Bad: "Successfully implemented feature X, ready for testing"
  - Good: "Implemented feature X, ready for testing"
  - Good: "Ran tests for feature X, they all completed successfully"