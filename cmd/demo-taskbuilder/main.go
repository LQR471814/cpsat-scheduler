package main

import (
	"cpsat-scheduler/internal/state"

	"charm.land/huh/v2"
)

type TaskBuilderForm struct {
	builder state.TaskBuilder
	form    *huh.Form
}

func NewTaskBuilderForm(builder state.TaskBuilder) (out TaskBuilderForm) {
	out.builder = builder
}

func main() {

}
