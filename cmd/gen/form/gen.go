package main

import (
	"fmt"
	"io"
	"strings"

	"charm.land/lipgloss/v2"
)

const (
	cmd_prompt_prefix       = "prompt prefix"
	cmd_next                = "next"
	cmd_submit              = "submit"
	cmd_cancel              = "cancel"
	cmd_help                = "help"
	cmd_params_postprocess  = "params post process"
	cmd_returns_postprocess = "returns post process"
)

var (
	nullType   = TypeDef{Type: "nothing"}
	boolType   = TypeDef{Type: "bool"}
	stringType = TypeDef{Type: "string"}
	anyType    = TypeDef{Type: "any"}
)

var indentStyle = lipgloss.NewStyle().MarginLeft(4)

func renderMargin(w io.Writer) {
	fmt.Fprint(w, "\n\n")
}

func indentText(text string) string {
	return indentStyle.Render(text)
}

func (d TypeDef) Render(w io.Writer) {
	fmt.Fprint(w, d.Type)

	if len(d.Fields) > 0 {
		fmt.Fprint(w, "<")
		i := 0
		for _, entry := range d.Fields {
			fmt.Fprint(w, entry.Key)
			fmt.Fprint(w, ": ")
			entry.Value.Render(w)
			if i < len(d.Fields)-1 {
				fmt.Fprint(w, ", ")
			}
			// oneof type as the last field breaks tree-sitter parsing irrevocably, this is a workaround
			if i == len(d.Fields)-1 && entry.Value.Type == "oneof" {
				fmt.Fprint(w, ", ")
			}
			i++
		}
		fmt.Fprint(w, ">")
		return
	}

	if len(d.Positional) > 0 {
		fmt.Fprint(w, "<")
		for i, def := range d.Positional {
			def.Render(w)
			if i < len(d.Positional)-1 {
				fmt.Fprint(w, ", ")
			}
		}
		fmt.Fprint(w, ">")
		return
	}
}

func (c Closure) Render(w io.Writer) {
	if strings.Contains(c.Name, " ") {
		fmt.Fprintf(w, `def "%s" [`, c.Name)
	} else {
		fmt.Fprintf(w, `def %s [`, c.Name)
	}
	i := 0
	for _, entry := range c.Params {
		fmt.Fprintf(w, "%s: ", entry.Key)
		entry.Value.Render(w)
		if i < len(c.Params)-1 {
			fmt.Fprint(w, ", ")
		}
		i++
	}
	fmt.Fprint(w, "]: ")
	c.In.Render(w)
	fmt.Fprint(w, " -> ")
	c.Out.Render(w)
	fmt.Fprint(w, " {\n")
	fmt.Fprint(w, indentText(string(c.Body)))
	fmt.Fprint(w, "\n}")
}

func (d FieldDef) getterFn() Closure {
	return Closure{
		Name:   fmt.Sprintf("get %s", d.Name),
		Params: nil,
		In:     nullType,
		Out:    d.Type,
		Body:   Block(d.ClosureBodies.Getter),
	}
}

func (d FieldDef) setterFn() Closure {
	return Closure{
		Name:   fmt.Sprintf("set %s", d.Name),
		Params: nil,
		In:     TypeDef{Type: "oneof", Positional: []TypeDef{d.Type, nullType}},
		Out:    nullType,
		Body:   Block(d.ClosureBodies.Setter),
	}
}

func (d FieldDef) setFn() Closure {
	return Closure{
		Name:   d.Name,
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   *d.Atomic.ClosureBodies.Set,
	}
}

func (d FieldDef) unsetFn() Closure {
	return Closure{
		Name:   fmt.Sprintf("unset %s", d.Name),
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   Block(fmt.Sprintf("null | set %s", d.Name)),
	}
}

func (d FieldDef) renderAtomicField(w io.Writer) {
	if d.Atomic.ClosureBodies.SetStatic != nil {
		d.Atomic.ClosureBodies.SetStatic.Render(w)
		renderMargin(w)
	}
	if d.Atomic.ClosureBodies.GetStatic != nil {
		d.Atomic.ClosureBodies.GetStatic.Render(w)
		renderMargin(w)
	}
	if d.Atomic.ClosureBodies.Set != nil {
		d.setFn().Render(w)
		renderMargin(w)
	}
	d.unsetFn().Render(w)
	renderMargin(w)
}

func (d FieldDef) addFn() Closure {
	return Closure{
		Name:   fmt.Sprintf("add %s", d.Name),
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   *d.List.ClosuresBodies.Add,
	}
}

func (d FieldDef) removeFn() Closure {
	if d.List.ClosuresBodies.Remove != nil {
		return *d.List.ClosuresBodies.Remove
	}
	displayValueCmd := fmt.Sprintf("to json -r")
	if d.ClosureBodies.DisplayValue != nil {
		displayValueCmd = fmt.Sprintf("display %s", d.Name)
	}
	body := fmt.Sprintf(
		`let element = get %[1]s
| each { %[2]s }
| enumerate
| rename id name
| util choose table --header "Choose a %[1]s to remove:"
if $element == null {
	return false
}
get %[1]s | drop nth $element.id | set %[1]s`,
		d.Name,
		displayValueCmd,
	)
	return Closure{
		Name:   fmt.Sprintf("remove %s", d.Name),
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   Block(body),
	}
}

func (d FieldDef) renderListField(w io.Writer) {
	d.removeFn().Render(w)
	renderMargin(w)

	if d.List.ClosuresBodies.Add != nil {
		d.addFn().Render(w)
		renderMargin(w)
	}

	if d.List.ClosuresBodies.AddStatic != nil {
		d.List.ClosuresBodies.AddStatic.Render(w)
		renderMargin(w)
	}

	if d.List.ClosuresBodies.List != nil {
		d.List.ClosuresBodies.List.Render(w)
		renderMargin(w)
	}
}

func (d FieldDef) displayValueFn() Closure {
	return Closure{
		Name:   fmt.Sprintf("display %s", d.Name),
		Body:   *d.ClosureBodies.DisplayValue,
		Params: nil,
		In:     d.Type,
		Out:    stringType,
	}
}

func (d FieldDef) validateFn() Closure {
	return Closure{
		Name:   fmt.Sprintf("validate %s", d.Name),
		Params: nil,
		In:     d.Type,
		Out:    boolType,
		Body:   *d.ClosureBodies.Validate,
	}
}

func (d FieldDef) Render(w io.Writer) {
	d.getterFn().Render(w)
	renderMargin(w)
	d.setterFn().Render(w)
	renderMargin(w)
	if d.ClosureBodies.Validate != nil {
		d.validateFn().Render(w)
		renderMargin(w)
	}
	if d.ClosureBodies.DisplayValue != nil {
		d.displayValueFn().Render(w)
		renderMargin(w)
	}
	if d.Atomic != nil {
		d.renderAtomicField(w)
		return
	}
	if d.List != nil {
		d.renderListField(w)
		return
	}
	panic("field must specify either atomic or list")
}

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
			switch field.Type.Type {
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
	return Closure{
		Name:   cmd_help,
		Params: nil,
		Body: Block(`[[group cmd desc];
	[common "status, s"       "Show form status."]
	[null   "next, n"         "Fill in next unfilled field."]
	[null   "submit, done, d" "Submit form."]
	[null   "cancel, c"       "Abort form."]
	[fields "<field>"         "Set field value with interactive picker."]
	[null   "set <field>"     "Set field value."]
	[null   "get <field>"     "Get field value."]
	[null   "unset <field>"   "Unset field value."]
	[lists  "add <field>"     "Add to list."]
	[null   "list <field>"    "List elements."]
	[null   "remove <field>"  "Remove from list interactively."]
]`),
		In: nullType,
		Out: TypeDef{
			Type: "table",
			Fields: []KeyValue[TypeDef]{
				{"group", TypeDef{Type: "oneof", Positional: []TypeDef{stringType, nullType}}},
				{"cmd", stringType},
				{"desc", stringType},
			},
		},
	}
}

func (f Form) renderAliasBlock(w io.Writer) {
	fmt.Fprint(w, `alias s = status
alias n = next
alias done = submit
alias d = submit
alias c = cancel`)
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

	f.renderAliasBlock(w)
	renderMargin(w)

	if f.Backmatter != nil {
		fmt.Fprint(w, *f.Backmatter)
	}
}
