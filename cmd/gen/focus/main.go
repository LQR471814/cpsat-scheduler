package main

import (
	"cpsat-scheduler/internal/gen"
	"fmt"
	"go/types"
	"log"

	. "github.com/dave/jennifer/jen"
)

func main() {
	ctx, err := gen.LoadContext()
	if err != nil {
		log.Fatal(err)
	}

	pkg := ctx.Package
	scope := pkg.Types.Scope()
	for _, name := range scope.Names() {
		obj := scope.Lookup(name)

		typeName, ok := obj.(*types.TypeName)
		if !ok {
			continue
		}

		named, ok := typeName.Type().(*types.Named)
		if !ok {
			continue
		}

		strct, ok := named.Underlying().(*types.Struct)
		if !ok {
			continue
		}

		fmt.Printf("struct: %s\n", name)

		for f := range strct.Fields() {
			fmt.Printf("  field: %s (%s)\n", f.Name(), f.Type())
		}
	}

	out := NewFile(pkg.Name)
	out.Func().Id("handleFocus").Params().Block()

	err = ctx.Generate(out)
	if err != nil {
		log.Fatal(err)
	}
}
