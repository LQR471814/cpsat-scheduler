package main

import (
	"cpsat-scheduler/internal/nugen"
	"fmt"
	"io"
	"strings"
)

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
	fmt.Fprintf(&body, `$env.state`)
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

func (f Form) renderAliasBlock(w io.Writer) {
	fmt.Fprint(w, `alias done = submit
alias d = submit
alias c = cancel`)
}
