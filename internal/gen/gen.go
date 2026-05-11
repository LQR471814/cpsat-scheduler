package gen

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/dave/jennifer/jen"
	"golang.org/x/tools/go/packages"
)

type Context struct {
	Package  *packages.Package
	Filepath string
	Filename string
}

func LoadContext() (ctx Context, err error) {
	cfg := &packages.Config{
		Mode: packages.NeedTypes | packages.NeedSyntax | packages.NeedTypesInfo | packages.NeedName,
		Dir:  ".",
	}
	pkgs, err := packages.Load(cfg, ".")
	if err != nil {
		return
	}
	ctx.Package = pkgs[0]
	ctx.Filepath = os.Getenv("GOFILE")
	file := filepath.Base(ctx.Filepath)
	ctx.Filename = strings.TrimSuffix(file, filepath.Ext(file))
	return
}

func (c Context) Generate(contents *jen.File) (err error) {
	f, err := os.Create(filepath.Join(".", fmt.Sprintf("%s_gen.go", c.Filename)))
	if err != nil {
		return
	}
	defer f.Close()
	err = contents.Render(f)
	return
}
