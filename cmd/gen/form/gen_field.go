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
	// we set --env by default because environment may be set inside functions
	if strings.Contains(c.Name, " ") {
		fmt.Fprintf(w, `def --env "%s" [`, c.Name)
	} else {
		fmt.Fprintf(w, `def --env %s [`, c.Name)
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
		Name:   fmt.Sprintf("%s", d.Name),
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   *d.List.ClosuresBodies.Add,
	}
}

func (d FieldDef) editFn() Closure {
	displayValueCmd := fmt.Sprintf("to json -r")
	if d.ClosureBodies.DisplayValue != nil {
		displayValueCmd = fmt.Sprintf("display %s", d.Name)
	}
	var body Block
	body = Block(fmt.Sprintf(
		`let element = get %[1]s
| each { %[2]s }
| enumerate
| rename id name
| util choose table --header "Choose a %[1]s to edit:"
if $element == null {
	return
}
try {
	let updated = (get %[1]s | get $element.id) | do {
	%[3]s
	}
	set (get %[1]s | update $element.id { $updated })
	
}
		`,
		d.Name,
		displayValueCmd,
		*d.List.ClosuresBodies.Edit,
	))
	return Closure{
		Name:   fmt.Sprintf("edit %s", d.Name),
		Params: nil,
		In:     nullType,
		Out:    nullType,
		Body:   body,
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
	return
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

	if d.List.ClosuresBodies.Edit != nil {
		d.editFn().Render(w)
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
		In:     TypeDef{Type: "oneof", Positional: []TypeDef{d.Type, nullType}},
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
