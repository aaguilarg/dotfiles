# Ruby on Rails conventions (any Rails project)

## Naming & structure
- Services: resource-named class + verb method (`InvoiceService.create`), never verb-named classes. Settle naming (propose options) BEFORE writing files.
- Arguments: a single argument stays positional only when the class/method name already says what it is (`ConnectionService.disconnect(connection)`); otherwise it's a keyword, even when it's the only one (`Client.new(cookie:)`). Two or more arguments are all keywords, the first included (`deliver(user:, text:)`), never "first positional, rest keywords". If a single argument's type is ambiguous, put it in the class name and keep it positional. Framework-defined signatures (controller actions, job `perform`) stay as the framework needs them, and so do class-level macros (`relation :name, serializer:`, like `has_many :x, dependent:`).
- Read constructor state through private `attr_reader`s, not `@ivars` (a memoized `@x ||=` is fine).
- Date columns and attributes end in `_on` (`recorded_on`, `started_on`), as timestamps end in `_at`; never a bare `date`.
- Dynamic dispatch: explicit frozen registry hash of class constants + `.fetch`, never string-built `constantize`.
- Guard clauses (`return x if ...`) over `||` chaining; extract a private method rather than `return`/`next` inside a block passed to another method.
- Shared job behavior: base job class, not a concern.
- State machines: AASM, namespaced when state names match column names; `timestamps: true` for `<state>_at` on states entered once. The `aasm` block holds only states, transitions, guards and timestamps; every side effect of an event goes to a `<Model>::StateMachine` collaborator through `delegate: true` events.

## Jobs & retries
- Let errors propagate so Sidekiq's default exponential backoff retries; avoid `retry_on`/`sidekiq_options` machinery unless an error is expected on most runs. Raise named errors (e.g. `FooNotReadyError`) from guards.
- Never hold a DB transaction or row lock across network calls; serialize check-then-create of external entities with `with_advisory_lock!` (session-level — breaks under PgBouncer transaction pooling; `transaction: true` would no-op it).

## Specs
- Doubles: `instance_double(Klass, method: value)`; assert enqueueing by stubbing the job class (`receive(:set)`/`receive(:perform_later)`) + `have_received`, not `have_been_enqueued`.
- Nesting: base case bare at the outer level, each nested context adds ONE record via `before`/`let!`, variations via overridable `let`s; `shared_examples` for repeated assertions.
- Job specs: split `describe '#perform_later'` (enqueue example) from `describe '#perform_now'` (behavior). Child-class specs stub the inherited helper on a held instance; the base spec owns the shared contract (write a base job spec whenever feasible).

## Style
- Near-zero comments: only non-obvious constraints the code can't express. Never narrate what the next line does.
- A string that doesn't fit on one line is a `<<~TEXT.squish` heredoc (interpolation still works), never `'…' \` concatenated across lines.

# Verification before reporting (any project)

- Re-verify identifiers/spelling against the real code before reporting a "finding" — grep typos and invented placeholders have produced false criticals.
- Never assert infra/logging/branch behavior without the actual output in hand.
- Read the working tree, not `git show <branch>:` — uncommitted edits are part of the truth.
- Confirm API fields on the serializer the consumer actually hits (app-facing vs internal) before calling them reachable.
- Long analyses (QA runs, metrics sweeps): write results to a file incrementally as each case completes; never accumulate one giant chat response.

# Code language

All code, tests, QA scripts, variable and helper names in English. User-facing copy and script *output* may be Spanish.

# Frontend/UI (RN + Vue)

- Navigation handlers arrive via props; components don't wire navigation directly.
- Match/reuse existing sheets and modals before creating new intermediate ones; keep scope minimal.
- Verify Figma colors by hex (pixel-sample the swatch), never by variable label; check displayed values/amounts against the mocks before finishing.

# Shell & tooling habits (fewer permission prompts)

Most prompts come from command *shape*, not missing allowlist entries (the safe read-only commands are already auto-allowed). Minimize them:
- Inspect files with the Read/Grep/Glob tools, not `cat`/`grep`/`find` shell compounds — tool calls never prompt.
- Parse JSON with `jq` or `gh ... --jq`, never `python3 -c` / `node -e` (arbitrary interpreters can't be allowlisted, so they always prompt).
- Run a single allowed command on its own; drop decorative `echo "=== … ===" && cmd` wrappers — a compound prompts if *any* segment isn't allowed.
- Avoid `for`/`while`/`if` shell loops when one command or a tool will do; a genuine loop will prompt once.

@~/dotfiles/private/claude/CLAUDE.md
