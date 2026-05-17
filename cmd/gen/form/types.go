package main

type KeyValue[T any] struct {
	Key   string `json:"key"`
	Value T      `json:"value"`
}

type Expr string

type Block string

type TypeDef struct {
	Type       string              `json:"type"`
	Fields     []KeyValue[TypeDef] `json:"fields,omitempty"`
	Positional []TypeDef           `json:"positional,omitempty"`
}

type Closure struct {
	Name   string              `json:"name"`
	Params []KeyValue[TypeDef] `json:"params"`
	Body   Block               `json:"body"`
	In     TypeDef             `json:"in"`
	Out    TypeDef             `json:"out"`
}

type FormClosures struct {
	// ParamPostProcess is body of []: params -> any
	ParamPostProcess *Block `json:"param_post_process"`
	// ReturnsPostProcess is body of []: returns -> any
	ReturnsPostProcess *Block `json:"returns_post_process"`
	// PromptPrefix is body of []: nothing -> string
	PromptPrefix *Block `json:"prompt_prefix"`
}

type FieldClosureBodies struct {
	// Getter is the body of a []: nothing -> field_type, it should retrieve
	// the current value of the field
	Getter Expr `json:"getter"`
	// Setter is the body of a []: field_type -> nothing, it should mutate the
	// value of the field to the input value of the closure
	Setter Expr `json:"setter"`
	// Validate is body of []: field_type -> oneof<string, nothing>
	Validate *Block `json:"validate"`
	// DisplayValue is body of []: field_type -> string
	DisplayValue *Block `json:"display_value"`
}

type FieldAtomicClosuresBodies struct {
	// Set is body of []: nothing -> nothing
	Set *Block `json:"set"`
	// SetStatic provides a non-interactive command that is more user-friendly
	// than directly using the setter, if not specified no command will be
	// generated
	SetStatic *Closure `json:"set_static"`
	// GetStatic provides a non-interactive command that provides more
	// user-friendly output than directly results from the getter, if not
	// specified, no function will be generated
	GetStatic *Closure `json:"get_static"`
}

type FieldAtomic struct {
	ClosureBodies FieldAtomicClosuresBodies `json:"closure_bodies"`
}

type FieldListClosuresBodies struct {
	// Add is body of []: nothing -> nothing
	Add *Block `json:"add"`
	// Edit is body of []: field_type -> field_type (may throw, which counts as abort)
	Edit      *Block   `json:"edit"`
	AddStatic *Closure `json:"add_static"`
	Remove    *Closure `json:"remove"`
	List      *Closure `json:"list"`
}

type FieldList struct {
	ClosuresBodies FieldListClosuresBodies `json:"closure_bodies"`
}

type FieldDef struct {
	Name          string             `json:"name"`
	DisplayName   string             `json:"display_name"`
	Type          TypeDef            `json:"type"`
	ClosureBodies FieldClosureBodies `json:"closure_bodies"`
	Atomic        *FieldAtomic       `json:"atomic"`
	List          *FieldList         `json:"list"`
}

type Form struct {
	Use         []string     `json:"use"`
	Name        string       `json:"name"`
	Frontmatter *Block       `json:"frontmatter"`
	Params      TypeDef      `json:"params"`
	Returns     TypeDef      `json:"returns"`
	Closures    FormClosures `json:"closures"`
	Fields      []FieldDef   `json:"fields"`
	Backmatter  *Block       `json:"backmatter"`
}
