package main

import (
	"cpsat-scheduler/internal/nugen"
	"fmt"
	"io"
	"strings"
)

func (f Form) promptPrefixFn() nugen.Closure {
	var body nugen.Block
	if f.Closures.PromptPrefix != nil {
		body = *f.Closures.PromptPrefix
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

func (f Form) statusFn() nugen.Closure {
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
	return nugen.Closure{
		Env:    true,
		Name:   "status",
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.NullType,
		Body:   nugen.Block(body.String()),
	}
}

func (f Form) nextFn() nugen.Closure {
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
			if field.List.ClosureBodies.Add != nil {
				fmt.Fprintf(&body, `if not (%[1]s | validate %[2]s) {
	%[2]s
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
	return nugen.Closure{
		Env:    true,
		Name:   cmd_next,
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     nugen.NullType,
		Out:    nugen.BoolType,
	}
}

func (f Form) submitFn() nugen.Closure {
	var body strings.Builder
	fmt.Fprintf(&body, `next
$env.state`)
	if f.Closures.ReturnsPostProcess != nil {
		fmt.Fprintf(&body, " | %s", cmd_returns_postprocess)
	}
	fmt.Fprint(&body, ` | util save form output
exit # nu-lint-ignore: exit_only_in_main`)
	return nugen.Closure{
		Env:    true,
		Name:   cmd_submit,
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     nugen.NullType,
		Out:    nugen.NullType,
	}
}

func (f Form) cancelFn() nugen.Closure {
	var body strings.Builder
	fmt.Fprintln(&body, `if not (util confirm --prompt 'Are you sure you want to abort? (changes will not be saved)') { return }`)
	fmt.Fprint(&body, `null`)
	fmt.Fprint(&body, ` | util save form output
exit # nu-lint-ignore: exit_only_in_main`)
	return nugen.Closure{
		Env:    true,
		Name:   cmd_cancel,
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     nugen.NullType,
		Out:    nugen.NullType,
	}
}

func (f Form) paramsPostProcessFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   cmd_params_postprocess,
		Params: nil,
		In:     f.Params,
		Out:    nugen.AnyType,
		Body:   *f.Closures.ParamPostProcess,
	}
}

func (f Form) returnsPostProcessFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   cmd_returns_postprocess,
		Params: nil,
		In:     nugen.AnyType,
		Out:    f.Returns,
		Body:   *f.Closures.ReturnsPostProcess,
	}
}

func (f Form) helpFn() nugen.Closure {
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
			fmt.Fprintf(&body, `	["%s" `, f.Name)
		} else {
			fmt.Fprint(&body, `	[null `)
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
			if f.List.ClosureBodies.Add != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Interactively add a %s.']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.List.ClosureBodies.AddStatic != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Add a %s via nushell command.']\n",
					f.List.ClosureBodies.AddStatic.Name,
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
			if f.List.ClosureBodies.Edit != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'edit %s' 'Edit a %s']\n",
					f.Name,
					f.DisplayName,
				)
			}
			if f.List.ClosureBodies.Remove != nil {
				writePrefix(f)
				fmt.Fprintf(
					&body,
					"'%s' 'Remove a %s']\n",
					f.List.ClosureBodies.Remove.Name,
					f.DisplayName,
				)
			}
		}
	}
	fmt.Fprintln(&body, "]")
	return nugen.Closure{
		Name:   cmd_help,
		Params: nil,
		Body:   nugen.Block(body.String()),
		In:     nugen.NullType,
		Out:    nugen.NullType,
	}
}

func (f Form) renderAliasBlock(w io.Writer) {
	fmt.Fprint(w, `alias done = submit
alias d = submit
alias c = cancel`)
}

func (f Form) Render(w io.Writer) {
	f.renderSetupBlock(w)
	nugen.RenderMargin(w)

	if f.Frontmatter != nil {
		fmt.Fprint(w, *f.Frontmatter)
		nugen.RenderMargin(w)
	}
	if f.Closures.ParamPostProcess != nil {
		f.paramsPostProcessFn().Render(w)
		nugen.RenderMargin(w)
	}
	if f.Closures.ReturnsPostProcess != nil {
		f.returnsPostProcessFn().Render(w)
		nugen.RenderMargin(w)
	}

	f.promptPrefixFn().Render(w)
	nugen.RenderMargin(w)

	for _, field := range f.Fields {
		field.Render(w)
	}

	if len(f.Fields) > 0 {
		f.statusFn().Render(w)
		nugen.RenderMargin(w)
		fmt.Fprintln(w, `alias s = status`)

		f.nextFn().Render(w)
		nugen.RenderMargin(w)
		fmt.Fprintln(w, "alias n = next")

		f.helpFn().Render(w)
		nugen.RenderMargin(w)
		fmt.Fprintln(w, `alias h = help`)
	}

	f.submitFn().Render(w)
	nugen.RenderMargin(w)

	f.cancelFn().Render(w)
	nugen.RenderMargin(w)

	f.renderAliasBlock(w)
	nugen.RenderMargin(w)

	if f.Backmatter != nil {
		fmt.Fprint(w, *f.Backmatter)
		nugen.RenderMargin(w)
	} else {
		fmt.Fprint(w, `status
help`)
	}
}
