---
trigger: always_on
---

# Purpose

automated scheduling of personal task based on op. research

# Architecture

- python cp-sat solver model convert high-level task def. -> low-level model and solve `/solver/`
- go backend, manage state of high-level task def., provide API intf. `/cmd/`, `/internal/`
- nushell CLI frontend <-> go backend `/cli/`
- gRPC facilitate go <-> nushell `/proto/`
- [codegen](/docs/CODEGEN.md)
    - look at [types.go](/cmd/gen/form/types.go) for .spec.nu form shape

# Scripts

- `nix develop` - always run first -> activate dev env
- `go run ./cmd/api` - run go backend
- `nu gen_proto.nu` - codegen after change to .proto
- `nu gen_db.nu` - codegen after change to .sql
- `nu gen_forms.nu` - codegen after change to .spec.nu

