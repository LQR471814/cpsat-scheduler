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
	KeyAccess Expr `json:"key_access"`
	// Validate is body of []: field_type -> oneof<string, nothing>
	Validate *Block `json:"validate"`
	// DisplayValue is body of []: field_type -> string
	DisplayValue *Block `json:"display_value"`
}

type FieldAtomicClosuresBodies struct {
	// Set is body of []: nothing -> nothing
	Set       *Block   `json:"set"`
	SetStatic *Closure `json:"set_static"`
	GetStatic *Closure `json:"get_static"`
}

type FieldAtomic struct {
	ClosureBodies FieldAtomicClosuresBodies `json:"closure_bodies"`
}

type FieldListClosuresBodies struct {
	// Add is body of []: nothing -> nothing
	Add       *Block   `json:"add"`
	AddStatic *Closure `json:"add_static"`
	// Remove is body of []: nothing -> nothing
	Remove *Block `json:"remove"`
	// List is body of []: nothing -> any
	List *Block `json:"list"`
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
