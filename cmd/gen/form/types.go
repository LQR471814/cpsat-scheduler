package main

import "cpsat-scheduler/internal/nugen"

// FormClosures defines custom Nushell script blocks executed at specific
// points in the lifecycle of a Form.
type FormClosures struct {
	// ParamPostProcess is the body of a closure that converts incoming
	// parameters before they are saved to the form's state ($env.state).
	//
	// Signature:
	//
	//	[]: params -> any
	ParamPostProcess *nugen.Block `json:"param_post_process"`

	// ReturnsPostProcess is the body of a closure that converts the form's
	// state ($env.state) before it is returned as the final form output.
	//
	// Signature:
	//
	//	[]: returns -> any
	ReturnsPostProcess *nugen.Block `json:"returns_post_process"`

	// PromptPrefix is the body of a closure that overrides the default prompt
	// prefix function.
	//
	// Signature:
	//
	//	[]: nothing -> string
	PromptPrefix *nugen.Block `json:"prompt_prefix"`
}

// FieldClosureBodies defines the core Nushell expressions and blocks used to
// get, set, validate, and format the value of a form field.
type FieldClosureBodies struct {
	// Getter is the body of a closure that retrieves the current value of the
	// field.
	//
	// Signature:
	//
	//	[]: nothing -> field_type
	Getter nugen.Expr `json:"getter"`

	// Setter is the body of a closure that mutates the value of the field to
	// the input value.
	//
	// Signature:
	//
	//	[]: field_type -> nothing
	Setter nugen.Expr `json:"setter"`

	// Validate is the body of a closure that validates the field's value. It
	// should return true if the field is valid, or false otherwise. If null,
	// validation always passes.
	//
	// Signature:
	//
	//	[]: field_type -> bool
	Validate *nugen.Block `json:"validate"`

	// DisplayValue is the body of a closure that formats the field's value for
	// human-friendly display.
	//
	// Signature:
	//
	//	[]: field_type -> string
	DisplayValue *nugen.Block `json:"display_value"`
}

// FieldAtomicClosuresBodies defines closures used for interacting with and
// managing a single-value (atomic) form field.
type FieldAtomicClosuresBodies struct {
	// Set is the body of a closure that provides an interactive way for the
	// user to set the field's value. If null, no interactive command is
	// generated. The generated command name will be the field name.
	//
	// Signature:
	//
	//	[]: nothing -> nothing
	Set *nugen.Block `json:"set"`

	// SetStatic should provide a non-interactive Nushell command to set the
	// field's value. This should be more user-friendly than directly invoking
	// the underlying setter. If null, no static setter command is generated.
	SetStatic *nugen.Closure `json:"set_static"`

	// GetStatic should provide a non-interactive Nushell command that outputs
	// the field's value in a more human-friendly format than the raw getter.
	// If null, no static getter command is generated.
	GetStatic *nugen.Closure `json:"get_static"`
}

// FieldAtomic represents the configuration for an atomic (scalar) field,
// housing the closure bodies that define its behavior.
type FieldAtomic struct {
	ClosureBodies FieldAtomicClosuresBodies `json:"closure_bodies"`
}

// FieldListClosuresBodies defines closures used to manage list-based form
// fields, including adding, editing, removing, and listing elements.
type FieldListClosuresBodies struct {
	// Add is the body of a closure that provides an interactive way to append
	// a new element to the list. If null, no interactive add command is
	// generated. The generated command name is `add <field_name>`.
	//
	// Signature:
	//
	//	[]: nothing -> nothing
	Add *nugen.Block `json:"add"`

	// Edit is the body of a closure that provides an interactive way to edit
	// an existing list element. Throwing an error inside this block counts as
	// an edit abort. If null, no command is generated. The generated command
	// name is `edit <field_name>`.
	//
	// Signature:
	//
	//	[]: null -> null
	Edit *nugen.Block `json:"edit"`

	// AddStatic should provide a non-interactive Nushell command to add an
	// element to the list. This should be more user-friendly than directly
	// manipulating the list via setter. If null, no static add command is
	// generated.
	AddStatic *nugen.Closure `json:"add_static"`

	// Remove provides an interactive way to select and remove an element from
	// the list. If null, it is auto-generated using the field's display_value
	// closure as representation.
	Remove *nugen.Closure `json:"remove"`

	// List provides a human-friendly tabular or text view of all items in the
	// list. If null, no custom list representation command is generated.
	List *nugen.Closure `json:"list"`
}

// FieldList represents the configuration for a list-based field, housing the
// closure bodies that define list actions.
type FieldList struct {
	ClosuresBodies FieldListClosuresBodies `json:"closure_bodies"`
}

// FieldDef defines the complete configuration for a form field, including its
// metadata, type, core closures, and atomic/list-specific handlers.
type FieldDef struct {
	// Name is the unique internal identifier for the field (e.g., used in code
	// and JSON keys).
	Name string `json:"name"`

	// DisplayName is the user-facing CLI label shown to the user during form
	// interactions.
	DisplayName string `json:"display_name"`

	// Type represents the underlying Nushell schema type of the field (e.g.,
	// int, string, record).
	Type nugen.TypeDef `json:"type"`

	// ClosureBodies contains the core getters, setters, validators, and
	// formatters for the field.
	ClosureBodies FieldClosureBodies `json:"closure_bodies"`

	// Atomic configures scalar editing commands if this field represents a
	// single value. Only one of Atomic or List should be configured.
	Atomic *FieldAtomic `json:"atomic"`

	// List configures collection editing commands if this field represents a
	// list of values. Only one of Atomic or List should be configured.
	List *FieldList `json:"list"`
}

// Form represents the top-level specification for a generated Nushell
// interactive form. It maps directly to declarative Nushell `.spec.nu` record
// definitions.
type Form struct {
	// Use is a list of external Nushell module paths to import at the top of
	// the generated form script.
	Use []string `json:"use"`

	// Name is the unique identifier and command name of the form (e.g.,
	// `create-task`).
	Name string `json:"name"`

	// Frontmatter is an optional Nushell code block run immediately when the
	// form starts.
	Frontmatter *nugen.Block `json:"frontmatter"`

	// Params defines the input schema/type of parameters required to launch
	// the form.
	Params nugen.TypeDef `json:"params"`

	// Returns defines the output schema/type returned by the form upon
	// successful submission.
	Returns nugen.TypeDef `json:"returns"`

	// Closures contains custom lifecycle closures for parameters, returns, and
	// prompts.
	Closures FormClosures `json:"closures"`

	// Fields is the list of fields that make up the form's interactive inputs.
	Fields []FieldDef `json:"fields"`

	// Backmatter is an optional Nushell code block run at completion or
	// teardown of the form.
	Backmatter *nugen.Block `json:"backmatter"`
}
