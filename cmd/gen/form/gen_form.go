package main

import (
	"cpsat-scheduler/internal/nugen"
	"fmt"
	"io"
	"strings"
)

func (f Form) promptPrefixFn() nugen.Closure {
	var body nugen.Block
	if f.PromptPrefix != nil {
		body = *f.PromptPrefix
	} else {
		body = nugen.Block(fmt.Sprintf(`$"($p.prompt_prefix) \(%s\)"`, f.Name))
	}
	return nugen.Closure{
		Name:   cmd_prompt_prefix,
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.StringType,
		Body:   nugen.Block(body),
	}
}

func (f Form) renderSetupBlock(w io.Writer) {
	for _, imp := range f.Use {
		fmt.Fprintf(w, "use '%s'\n", imp)
	}

	fmt.Fprintln(w, "use index.nu")
	fmt.Fprintln(w, "use ../../lib/util.nu")
	fmt.Fprintln(w, "use ../../proto/apipb/api.gen.nu")
	fmt.Fprintln(w)

	fmt.Fprint(w, `let __input: record<prompt_prefix: string, params: `)
	f.Params.Render(w)
	fmt.Fprintf(w, `> = util get form params

let prompt_prefix = $__input.prompt_prefix
let params = $__input.params

let default_prompt_prefix = $env.PROMPT_COMMAND
$env.PROMPT_COMMAND = {|| $"(%s) ($in | do $default_prompt_prefix)" }`, cmd_prompt_prefix)
}

func (f Form) cmdsFn() nugen.Closure {
	var body strings.Builder

	fmt.Fprint(&body, `print [[group cmd aliases desc];
`)
	for _, cmd := range f.Commands {
		fmt.Fprintf(&body, `	["%s" "%s" [`, cmd.Group, cmd.Closure.Name)
		for _, alias := range cmd.Aliases {
			fmt.Fprintf(&body, `"%s" `, alias)
		}
		fmt.Fprint(&body, `] "`)
		fmt.Fprint(&body, cmd.Desc)
		fmt.Fprint(&body, `"]
`)
	}
	fmt.Fprintln(&body, "]")

	return nugen.Closure{
		Name:   cmd_cmds,
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     nugen.NullType,
		Out:    nugen.NullType,
	}
}

func (f Form) returnsFn() nugen.Closure {
	var body strings.Builder
	fmt.Fprintln(&body, `util save form output
exit`)
	return nugen.Closure{
		Name:   "form return",
		In:     f.Returns,
		Out:    nugen.NullType,
		Params: nil,
		Export: false,
		Env:    false,
	}
}

func (f Form) Render(w io.Writer) {
	f.renderSetupBlock(w)
	nugen.RenderMargin(w)

	f.promptPrefixFn().Render(w)
	nugen.RenderMargin(w)

	f.returnsFn().Render(w)
	nugen.RenderMargin(w)

	for _, cmd := range f.Commands {
		cmd.Closure.Render(w)
		nugen.RenderMargin(w)
	}

	if f.Init != nil {
		fmt.Fprint(w, *f.Init)
		nugen.RenderMargin(w)
	}
}
