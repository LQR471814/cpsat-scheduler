package main

import (
	"cpsat-scheduler/internal/nugen"
	"fmt"
	"io"
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

func (d FieldDef) getterFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("get %s", d.Name),
		Params: nil,
		In:     nugen.NullType,
		Out:    d.Type,
		Body:   nugen.Block(d.ClosureBodies.Getter),
	}
}

func (d FieldDef) setterFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("set %s", d.Name),
		Params: nil,
		In:     nugen.TypeDef{Type: "oneof", Positional: []nugen.TypeDef{d.Type, nugen.NullType}},
		Out:    nugen.NullType,
		Body:   nugen.Block(d.ClosureBodies.Setter),
	}
}

func (d FieldDef) setFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   d.Name,
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.NullType,
		Body:   *d.Atomic.ClosureBodies.Set,
	}
}

func (d FieldDef) unsetFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("unset %s", d.Name),
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.NullType,
		Body:   nugen.Block(fmt.Sprintf("null | set %s", d.Name)),
	}
}

func (d FieldDef) renderAtomicField(w io.Writer) {
	if d.Atomic.ClosureBodies.SetStatic != nil {
		d.Atomic.ClosureBodies.SetStatic.Env = true
		d.Atomic.ClosureBodies.SetStatic.Render(w)
		nugen.RenderMargin(w)
	}
	if d.Atomic.ClosureBodies.GetStatic != nil {
		d.Atomic.ClosureBodies.GetStatic.Env = true
		d.Atomic.ClosureBodies.GetStatic.Render(w)
		nugen.RenderMargin(w)
	}
	if d.Atomic.ClosureBodies.Set != nil {
		d.setFn().Render(w)
		nugen.RenderMargin(w)
	}
	d.unsetFn().Render(w)
	nugen.RenderMargin(w)
}

func (d FieldDef) addFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("%s", d.Name),
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.NullType,
		Body:   *d.List.ClosuresBodies.Add,
	}
}

func (d FieldDef) editFn() nugen.Closure {
	displayValueCmd := fmt.Sprintf("to json -r")
	if d.ClosureBodies.DisplayValue != nil {
		displayValueCmd = fmt.Sprintf("display %s", d.Name)
	}
	var body nugen.Block
	body = nugen.Block(fmt.Sprintf(
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
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("edit %s", d.Name),
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.NullType,
		Body:   body,
	}
}

func (d FieldDef) removeFn() nugen.Closure {
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
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("remove %s", d.Name),
		Params: nil,
		In:     nugen.NullType,
		Out:    nugen.NullType,
		Body:   nugen.Block(body),
	}
}

func (d FieldDef) renderListField(w io.Writer) {
	d.removeFn().Render(w)
	nugen.RenderMargin(w)

	if d.List.ClosuresBodies.Add != nil {
		d.addFn().Render(w)
		nugen.RenderMargin(w)
	}

	if d.List.ClosuresBodies.Edit != nil {
		d.editFn().Render(w)
		nugen.RenderMargin(w)
	}

	if d.List.ClosuresBodies.AddStatic != nil {
		d.List.ClosuresBodies.AddStatic.Env = true
		d.List.ClosuresBodies.AddStatic.Render(w)
		nugen.RenderMargin(w)
	}

	if d.List.ClosuresBodies.List != nil {
		d.List.ClosuresBodies.List.Env = true
		d.List.ClosuresBodies.List.Render(w)
		nugen.RenderMargin(w)
	}
}

func (d FieldDef) displayValueFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("display %s", d.Name),
		Body:   *d.ClosureBodies.DisplayValue,
		Params: nil,
		In:     d.Type,
		Out:    nugen.StringType,
	}
}

func (d FieldDef) validateFn() nugen.Closure {
	return nugen.Closure{
		Env:    true,
		Name:   fmt.Sprintf("validate %s", d.Name),
		Params: nil,
		In:     nugen.TypeDef{Type: "oneof", Positional: []nugen.TypeDef{d.Type, nugen.NullType}},
		Out:    nugen.BoolType,
		Body:   *d.ClosureBodies.Validate,
	}
}

func (d FieldDef) Render(w io.Writer) {
	if d.ClosureBodies.Getter == "" {
		panic("assert failed: getter should not be empty")
	}
	if d.ClosureBodies.Setter == "" {
		panic("assert failed: setter should not be empty")
	}
	d.getterFn().Render(w)
	nugen.RenderMargin(w)
	d.setterFn().Render(w)
	nugen.RenderMargin(w)
	if d.ClosureBodies.Validate != nil {
		d.validateFn().Render(w)
		nugen.RenderMargin(w)
	}
	if d.ClosureBodies.DisplayValue != nil {
		d.displayValueFn().Render(w)
		nugen.RenderMargin(w)
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
