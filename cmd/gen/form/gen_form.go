package main

import (
	"fmt"
	"io"
	"strings"
)

func (f Form) promptPrefixFn() Closure {
	var body Block
	if f.Closures.PromptPrefix != nil {
		body = *f.Closures.PromptPrefix
	} else {
		body = Block(fmt.Sprintf(`$"($p.prompt_prefix) \(%s\)"`, f.Name))
	}
	return Closure{
		Name:   cmd_prompt_prefix,
		Params: nil,
		In:     nullType,
		Out:    stringType,
		Body:   Block(body),
	}
}

func (f Form) renderSetupBlock(w io.Writer) {
	for _, imp := range f.Use {
		fmt.Fprintf(w, "use '%s'\n", imp)
	}
	fmt.Fprintln(w)
	fmt.Fprint(w, `let p: record<prompt_prefix: string, state: `)
	f.Params.Render(w)
	fmt.Fprintf(w, `> = util get form params

let cmd = $env.PROMPT_COMMAND

$env.PROMPT_COMMAND = {|| $"(%s) ($in | do $cmd)" }

$env.state = $p.state`, cmd_prompt_prefix)
	if f.Closures.ParamPostProcess != nil {
		fmt.Fprintf(w, ` | %s

`, cmd_params_postprocess)
	}

}

func (f Form) statusFn() Closure {
	var body strings.Builder
	fmt.Fprintf(&body, "util print section title 'Form: %s'\n", f.Name)
	for _, field := range f.Fields {
		fmt.Fprintf(&body, "util print label '%s'\n", field.DisplayName)
		if field.ClosureBodies.DisplayValue != nil {
			fmt.Fprintf(
				&body,
				"print (%s | display %s)\n",
				field.ClosureBodies.Getter,
				field.Name,
			)
		} else {
			underlying := field.Type.Type
			if field.Type.Type == "oneof" && len(field.Type.Positional) == 2 {
				if field.Type.Positional[0].Type == "nothing" {
					underlying = field.Type.Positional[1].Type
				} else if field.Type.Positional[1].Type == "nothing" {
					underlying = field.Type.Positional[0].Type
				}
			}
			switch underlying {
			case "datetime":
				fmt.Fprint(&body, "util print date")
			case "duration":
				fmt.Fprint(&body, "util print duration")
			default:
				fmt.Fprint(&body, "print")
			}
			fmt.Fprintf(&body, " (%s)\n", field.ClosureBodies.Getter)
		}
		fmt.Fprint(&body, "print \"\"\n")
	}
	return Closure{
		Name:   "status",
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   Block(body.String()),
	}
}

func (f Form) nextFn() Closure {
	var body strings.Builder
	fmt.Fprintln(&body, "# nu-lint-ignore: print_and_return_data")
	for _, field := range f.Fields {
		if field.ClosureBodies.Validate == nil {
			continue
		}
		if field.Atomic != nil {
			if field.Atomic.ClosureBodies.Set != nil {
				fmt.Fprintf(&body, `if not (%[1]s | validate %[2]s) {
	%[2]s
	if not (%[1]s | validate %[2]s) { return false }
	return (next)
}
`, field.ClosureBodies.Getter, field.Name)
			} else {
				fmt.Fprintf(&body, `if not (%[1]s | validate %[2]s) {
	print "set %[2]s with 'set %[2]s'"
	return false
}
`, field.ClosureBodies.Getter, field.Name)
			}
		} else if field.List != nil {
			if field.List.ClosuresBodies.Add != nil {
				fmt.Fprintf(&body, `if not (%[1]s | validate %[2]s) {
	add %[2]s
	if not (%[1]s | validate %[2]s) { return false }
	return (next)
}
`, field.ClosureBodies.Getter, field.Name)
			} else {
				fmt.Fprintf(&body, `if not (%[1]s | validate %[2]s) {
	print "add a %[2]s with 'add %[2]s'"
	return false
}
`, field.ClosureBodies.Getter, field.Name)
			}
		}
	}
	fmt.Fprint(&body, "true")
	return Closure{
		Name:   cmd_next,
		Params: nil,
		Body:   Block(body.String()),
		In:     nullType,
		Out:    boolType,
	}
}

func (f Form) submitFn() Closure {
	var body strings.Builder
	fmt.Fprintf(&body, `next
$env.state`)
	if f.Closures.ReturnsPostProcess != nil {
		fmt.Fprintf(&body, " | %s", cmd_returns_postprocess)
	}
	fmt.Fprint(&body, ` | util save form output
exit # nu-lint-ignore: exit_only_in_main`)
	return Closure{
		Name:   cmd_submit,
		Params: nil,
		Body:   Block(body.String()),
		In:     nullType,
		Out:    nullType,
	}
}

func (f Form) cancelFn() Closure {
	var body strings.Builder
	fmt.Fprintln(&body, `if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }`)
	fmt.Fprint(&body, `null`)
	fmt.Fprint(&body, ` | util save form output
exit # nu-lint-ignore: exit_only_in_main`)
	return Closure{
		Name:   cmd_cancel,
		Params: nil,
		Body:   Block(body.String()),
		In:     nullType,
		Out:    nullType,
	}
}

func (f Form) paramsPostProcessFn() Closure {
	return Closure{
		Name:   cmd_params_postprocess,
		Params: nil,
		In:     f.Params,
		Out:    anyType,
		Body:   *f.Closures.ParamPostProcess,
	}
}

func (f Form) returnsPostProcessFn() Closure {
	return Closure{
		Name:   cmd_returns_postprocess,
		Params: nil,
		In:     anyType,
		Out:    f.Returns,
		Body:   *f.Closures.ReturnsPostProcess,
	}
}

func (f Form) helpFn() Closure {
	var body strings.Builder
	fmt.Fprint(&body, `print [[group cmd desc];
	[common "status, s" "Show form status."]
	[null "next, n" "Fill in next unfilled field."]
	[null "submit, done, d" "Submit form."]
	[null "cancel, c" "Abort form."]
`)
	prevGroup := "common"
	writePrefix := func(f FieldDef) {
		if f.Name != prevGroup {
			fmt.Fprintf(&body, `["%s" `, f.Name)
		} else {
			fmt.Fprint(&body, `[null `)
		}
		prevGroup = f.Name
	}
	for _, f := range f.Fields {
		if f.Atomic != nil {
			if f.Atomic.ClosureBodies.Set != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Interactively set %s.']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.Atomic.ClosureBodies.SetStatic != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Set %s via nushell command.']\n",
					f.Atomic.ClosureBodies.SetStatic.Name,
					f.DisplayName,
				)
			} else {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'set %s' 'Set %s via nushell command.']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.Atomic.ClosureBodies.GetStatic != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Get %s via nushell command.']\n",
					f.Atomic.ClosureBodies.GetStatic.Name,
					f.DisplayName,
				)
			} else {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'get %s' 'Get %s via nushell command.']\n",
					f.Name,
					f.DisplayName,
				)
			}
		} else if f.List != nil {
			if f.List.ClosuresBodies.Add != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Interactively add a %s.']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.List.ClosuresBodies.AddStatic != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Add a %s via nushell command.']\n",
					f.List.ClosuresBodies.AddStatic.Name,
					f.DisplayName,
				)
			} else {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'add %s' 'Add a %s via nushell command.']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.List.ClosuresBodies.Edit != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'edit %s' 'Edit a %s']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.List.ClosuresBodies.Remove != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Remove a %s']\n",
					f.List.ClosuresBodies.Remove.Name,
					f.DisplayName,
				)
			}
		}
	}
	fmt.Fprintln(&body, "]")
	return Closure{
		Name:   cmd_help,
		Params: nil,
		Body:   Block(body.String()),
		In:     nullType,
		Out:    nullType,
	}
}

func (f Form) renderAliasBlock(w io.Writer) {
	fmt.Fprint(w, `alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel

status
help`)
}

func (f Form) Render(w io.Writer) {
	f.renderSetupBlock(w)
	renderMargin(w)

	if f.Frontmatter != nil {
		fmt.Fprint(w, *f.Frontmatter)
		renderMargin(w)
	}
	if f.Closures.ParamPostProcess != nil {
		f.paramsPostProcessFn().Render(w)
		renderMargin(w)
	}
	if f.Closures.ReturnsPostProcess != nil {
		f.returnsPostProcessFn().Render(w)
		renderMargin(w)
	}

	f.promptPrefixFn().Render(w)
	renderMargin(w)

	for _, field := range f.Fields {
		field.Render(w)
	}

	f.statusFn().Render(w)
	renderMargin(w)

	f.nextFn().Render(w)
	renderMargin(w)

	f.submitFn().Render(w)
	renderMargin(w)

	f.cancelFn().Render(w)
	renderMargin(w)

	f.helpFn().Render(w)
	renderMargin(w)

	if f.Backmatter != nil {
		fmt.Fprint(w, *f.Backmatter)
		renderMargin(w)
	}

	f.renderAliasBlock(w)
	renderMargin(w)
}
