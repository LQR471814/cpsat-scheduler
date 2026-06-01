package main

import "cpsat-scheduler/internal/nugen"

// CommandDef defines a nushell command exposed in the form that may be part of
// a group and have some aliases.
type CommandDef struct {
	Desc    string        `json:"desc"`
	Group   string        `json:"group"`
	Aliases []string      `json:"aliases"`
	Closure nugen.Closure `json:"closure"`
}

// Form represents the top-level specification for a generated Nushell
// interactive form. It maps directly to declarative Nushell `.spec.nu` record
// definitions.
type Form struct {
	// Name is the unique identifier and command name of the form (e.g.,
	// `create-task`).
	Name string `json:"name"`

	// Params defines the input schema/type of parameters required to launch
	// the form.
	Params nugen.TypeDef `json:"params"`

	// Returns defines the output schema/type returned by the form upon
	// successful submission.
	Returns nugen.TypeDef `json:"returns"`

	// State defines mutable global variables in the form, for each entry of
	// `<key>: <type>`, 2 commands will be generated:
	//
	// - `r <key>: nothing -> <type>`
	// - `w <key>: <type> -> nothing`
	State []nugen.KeyValue[nugen.TypeDef] `json:"state"`

	// Use is a list of external Nushell module paths to import at the top of
	// the generated form script.
	Use []string `json:"use"`

	// Commands defines the commands in the body of the form.
	Commands []CommandDef `json:"commands"`

	// Init defines the initial script executed by commands in the form body.
	Init *nugen.Block `json:"init"`

	// PromptPrefix optionally overrides the prompt prefix function body of
	// nothing -> string, with no arguments.
	//
	// Note: the default prompt prefix function is stored as a closure called
	// `default_prompt_prefix`, which you can call with `do
	// $default_prompt_prefix`.
	PromptPrefix *nugen.Block `json:"prompt_prefix"`
}

// Form should generate:
// - use frontmatter
// - `$params` variable which is of type Params
// - `$prompt_prefix` variable which gives the input prompt prefix
// - state getter/setter
// - commands
// - init block
