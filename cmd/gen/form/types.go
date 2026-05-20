package main

import "cpsat-scheduler/internal/nugen"

type FormClosures struct {
	// ParamPostProcess is body of []: params -> any
	ParamPostProcess *nugen.Block `json:"param_post_process"`
	// ReturnsPostProcess is body of []: returns -> any
	ReturnsPostProcess *nugen.Block `json:"returns_post_process"`
	// PromptPrefix is body of []: nothing -> string
	PromptPrefix *nugen.Block `json:"prompt_prefix"`
}

type FieldClosureBodies struct {
	// Getter is the body of a []: nothing -> field_type, it should retrieve
	// the current value of the field
	Getter nugen.Expr `json:"getter"`
	// Setter is the body of a []: field_type -> nothing, it should mutate the
	// value of the field to the input value of the closure
	Setter nugen.Expr `json:"setter"`
	// Validate is body of []: field_type -> oneof<string, nothing>
	Validate *nugen.Block `json:"validate"`
	// DisplayValue is body of []: field_type -> string
	DisplayValue *nugen.Block `json:"display_value"`
}

type FieldAtomicClosuresBodies struct {
	// Set is body of []: nothing -> nothing
	Set *nugen.Block `json:"set"`
	// SetStatic provides a non-interactive command that is more user-friendly
	// than directly using the setter, if not specified no command will be
	// generated
	SetStatic *nugen.Closure `json:"set_static"`
	// GetStatic provides a non-interactive command that provides more
	// user-friendly output than directly results from the getter, if not
	// specified, no function will be generated
	GetStatic *nugen.Closure `json:"get_static"`
}

type FieldAtomic struct {
	ClosureBodies FieldAtomicClosuresBodies `json:"closure_bodies"`
}

type FieldListClosuresBodies struct {
	// Add is body of []: nothing -> nothing
	Add *nugen.Block `json:"add"`
	// Edit is body of []: field_type -> field_type (may throw, which counts as abort)
	Edit      *nugen.Block   `json:"edit"`
	AddStatic *nugen.Closure `json:"add_static"`
	Remove    *nugen.Closure `json:"remove"`
	List      *nugen.Closure `json:"list"`
}

type FieldList struct {
	ClosuresBodies FieldListClosuresBodies `json:"closure_bodies"`
}

type FieldDef struct {
	Name          string             `json:"name"`
	DisplayName   string             `json:"display_name"`
	Type          nugen.TypeDef      `json:"type"`
	ClosureBodies FieldClosureBodies `json:"closure_bodies"`
	Atomic        *FieldAtomic       `json:"atomic"`
	List          *FieldList         `json:"list"`
}

type Form struct {
	Use         []string      `json:"use"`
	Name        string        `json:"name"`
	Frontmatter *nugen.Block  `json:"frontmatter"`
	Params      nugen.TypeDef `json:"params"`
	Returns     nugen.TypeDef `json:"returns"`
	Closures    FormClosures  `json:"closures"`
	Fields      []FieldDef    `json:"fields"`
	Backmatter  *nugen.Block  `json:"backmatter"`
}
