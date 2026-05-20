# Code Generation (Codegen) Overview

This project heavily leverages code generation (codegen) to maintain type safety, reduce boilerplates, and build bridges between Go, Python, Nushell (CLI), and SQLite.

Three main codegen processes are configured via Nushell scripts (`gen_*.nu`) at the project root:

---

## 1. Database Code Generation (`gen_db.nu`)

- **Tool:** [sqlc](https://sqlc.dev/)
- **Configuration:** `sqlc.yaml`
- **Inputs:** 
  - Schema: `internal/state/db/schema.sql`
  - Queries: `internal/state/db/query.sql`
- **Output:** Type-safe Go database operations in `internal/state/db/`.
- **Command:** Runs `sqlc generate`.

---

## 2. Protocol Buffers & gRPC Generation (`gen_proto.nu`)

- **Tools:** `buf`, `python-grpc-tools-protoc`, and a custom `protoc-gen-nu` plugin.
- **Configuration:** `buf.yaml`, `buf.gen.yaml`
- **Inputs:** Protobuf definitions under `proto/`.
- **Outputs:**
  - **Python:** gRPC code generated into `solver/src/` for the CP-SAT solver backend.
  - **Go:** standard Go protobuf/gRPC code under `internal/`.
  - **Nushell:** Custom Nushell client bindings generated into `cli/lib/*.gen.nu`.
- **How Nushell Generation Works:**
  - `protoc-gen-nu` (located in `cmd/gen/protoc-gen-nu/`) is a custom `protoc` plugin written in Go.
  - It compiles protobuf RPC definitions and messages into Nushell records and typed closures.
  - It executes requests using `buf curl` communicating over a UNIX socket (`/tmp/cpsat-scheduler.api.sock`) to connect to the gRPC API.

---

## 3. Interactive CLI Forms Generation (`gen_forms.nu`)

- **Tool:** Go form-generator executable (`cmd/gen/form/`).
- **Inputs:** Nushell form specifications (`cli/**/*.spec.nu`).
- **How Form Generation Works:**
  - Form fields, layouts, validation, getters, and setters are described declaratively in a `*.spec.nu` Nushell record.
  - Running a `*.spec.nu` script serializes the specification to JSON.
  - The Go form-generator runner executes these specs, parses the JSON, and compiles them into fully-featured interactive TUI/CLI forms.
- **Outputs:**
  - Generated form scripts under `cli/forms/gen/`.
  - A form index module at `cli/forms/gen/index.nu`.
- **Validation:** Runs `nu-check --debug` on all generated files to guarantee Nushell syntax correctness.

### Form Spec Structure and Codegen Shape (`cmd/gen/form/types.go`)

The configuration structure and generated output shape are modeled directly after the Go structs defined in `cmd/gen/form/types.go`.

#### The `.spec.nu` File Structure

A form spec is a declarative Nushell script representing a `Form` struct. It maps to the following key configurations:

* **`name`** (string): The form's identifier.
* **`use`** (list of strings): External module paths to import in the generated script.
* **`params`** & **`returns`** (type definitions): The input and output schemas (e.g. `record`, `table`, `string`, `int`, `duration`, `datetime`).
* **`closures`** (record): Supports custom Nushell scripts for:
  - `prompt_prefix`: custom prompt text.
  - `param_post_process`: processing incoming form parameters.
  - `returns_post_process`: formatting outgoing form results (e.g. calling backend APIs).
* **`fields`** (list of records): A collection of fields matching the `FieldDef` Go struct:
  - `name` & `display_name` (strings): Internal field ID and user-facing CLI label.
  - `type` (type definition): Type of value the field holds.
  - `closure_bodies` (record): Scripts for field access and lifecycle:
    - `getter`: retrieves the current value of the field.
    - `setter`: updates the field value in the state.
    - `validate`: optional validation script returning a string error or nothing.
    - `display_value`: optional print formatting block.
  - **Atomic fields (`atomic`)**: Defines a scalar/single-value editor containing a custom `set` script, optional helper commands (`set_static`), and unset helper commands (`unset <field>`).
  - **List fields (`list`)**: Configures table/collection editors with action triggers (`add`, `edit`, `remove`, and `list`).
* **`frontmatter`** & **`backmatter`** (custom script blocks): Code runs immediately at startup or teardown/completion.

#### The Shape of Generated Forms
The generated Nushell scripts compile these declarative specs into command-driven interactive interfaces:
1. **State Initialization:** Imports dependencies and hooks `$env.PROMPT_COMMAND` to append the active form's context (e.g. `(profiles)`) to the CLI prompt.
2. **Accessors:** Compiles `getterFn()` and `setterFn()` for each field into strongly-typed Nushell environment-mutating commands (e.g. `def --env "get profiles"`, `def --env "set profiles"`).
3. **Helper & Interactive Editing Commands:** Compiles custom commands (e.g. `add profile`, `edit task`, `remove task`) that prompt the user, select list items via interactive tables, or trigger sub-forms.
4. **Form Navigation & Lifecycle Commands:** 
   - `status` (or `s`): Displays field values using default type printers or custom `display_value` closures.
   - `next` (or `n`): Walks through unfilled required/validating fields.
   - `submit` (or `done`/`d`): Commits and exits.
   - `cancel` (or `c`): Discards changes after confirmation and exits.
   - `help`: Generates tabular command menus.
