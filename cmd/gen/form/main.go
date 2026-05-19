package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
)

func readForm(ctx context.Context, path string) (form Form, err error) {
	cmd := exec.CommandContext(ctx, "nu", path)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return
	}
	err = cmd.Start()
	if err != nil {
		return
	}
	decoder := json.NewDecoder(stdout)
	err = decoder.Decode(&form)
	return
}

func findForms(ctx context.Context, dir string, out *[]FormSource) (err error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, e := range entries {
		if e.IsDir() {
			err = findForms(ctx, filepath.Join(dir, e.Name()), out)
			if err != nil {
				return
			}
			continue
		}
		if !strings.HasSuffix(e.Name(), ".spec.nu") {
			continue
		}
		src := filepath.Join(dir, e.Name())
		var form Form
		form, err = readForm(ctx, src)
		if err != nil {
			return
		}
		*out = append(*out, FormSource{
			Form: form,
			Path: src,
		})
	}
	return
}

func genProject(ctx context.Context, dir string) (err error) {
	project := Project{
		Path: dir,
	}
	err = findForms(ctx, dir, &project.Forms)
	if err != nil {
		err = fmt.Errorf("read forms: %w", err)
		return
	}
	err = project.Generate()
	if err != nil {
		err = fmt.Errorf("generate proj: %w", err)
		return
	}
	return
}

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	flag.Parse()
	dir := flag.Arg(0)
	if dir == "" {
		dir = "."
	}
	err := genProject(ctx, dir)
	if err != nil {
		log.Fatal(err)
	}
}
