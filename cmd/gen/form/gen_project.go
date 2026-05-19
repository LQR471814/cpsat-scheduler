package main

import (
	"fmt"
	"os"
	"path/filepath"
)

type FormSource struct {
	Path string
	Form Form
}

type Project struct {
	Path  string
	Forms []FormSource
}

func (p Project) generateForm(fsrc FormSource) (err error) {
	f, err := os.Create(filepath.Join(
		p.Path,
		"forms/gen",
		fmt.Sprintf("%s.gen.nu", fsrc.Form.Name),
	))
	if err != nil {
		return
	}
	defer f.Close()
	fsrc.Form.Render(f)
	return
}

func (p Project) generateFormIndex() (err error) {
	f, err := os.Create(filepath.Join(p.Path, "forms/gen/index.nu"))
	if err != nil {
		return
	}
	defer f.Close()

	fmt.Fprintln(f, "use ../../lib/util.nu")
	for _, fsrc := range p.Forms {
		fmt.Fprintf(f, `export def "form %s" []: `, fsrc.Form.Name)
		inp := TypeDef{
			Type: "record",
			Fields: []KeyValue[TypeDef]{
				{
					Key:   "prompt_prefix",
					Value: stringType,
				},
				{
					Key:   "state",
					Value: fsrc.Form.Params,
				},
			},
		}
		inp.Render(f)
		fmt.Fprint(f, " -> ")
		fsrc.Form.Returns.Render(f)
		fmt.Fprintf(f, ` {
	util exec "./forms/gen/%s.gen.nu" $in
}
`, fsrc.Form.Name)
	}
	return
}

func (p Project) Generate() (err error) {
	err = os.RemoveAll(filepath.Join(p.Path, "forms/gen"))
	if err != nil {
		return
	}
	err = os.MkdirAll(filepath.Join(p.Path, "forms/gen"), 0777)
	if err != nil {
		return
	}

	for _, fsrc := range p.Forms {
		err = p.generateForm(fsrc)
		if err != nil {
			return
		}
	}

	err = p.generateFormIndex()
	return
}
