package main

import (
	"encoding/json"
	"io"
	"log"
	"os"
)

func main() {
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		log.Fatal(err)
	}
	var form Form
	err = json.Unmarshal(input, &form)
	if err != nil {
		log.Fatal(err)
	}
	form.Render(os.Stdout)
}
