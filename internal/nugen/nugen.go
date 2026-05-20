package nugen

import (
	"fmt"
	"io"
	"strings"

	"charm.land/lipgloss/v2"
)

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
	Env    bool                `json:"env"`
	Export bool                `json:"export"`
}

var (
	NullType     = TypeDef{Type: "nothing"}
	BoolType     = TypeDef{Type: "bool"}
	StringType   = TypeDef{Type: "string"}
	AnyType      = TypeDef{Type: "any"}
	BinaryType   = TypeDef{Type: "binary"}
	FloatType    = TypeDef{Type: "float"}
	IntType      = TypeDef{Type: "int"}
	DurationType = TypeDef{Type: "duration"}
	DatetimeType = TypeDef{Type: "datetime"}
)

var indentStyle = lipgloss.NewStyle().MarginLeft(4)

func RenderMargin(w io.Writer) {
	fmt.Fprint(w, "\n\n")
}

func IndentText(text string) string {
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
	if c.Export {
		fmt.Fprint(w, "export ")
	}
	fmt.Fprint(w, "def ")
	if c.Env {
		fmt.Fprint(w, "--env ")
	}
	// we set --env by default because environment may be set inside functions
	if strings.Contains(c.Name, " ") {
		fmt.Fprintf(w, `"%s" [`, c.Name)
	} else {
		fmt.Fprintf(w, `%s [`, c.Name)
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
	fmt.Fprint(w, IndentText(string(c.Body)))
	fmt.Fprint(w, "\n}")
}
