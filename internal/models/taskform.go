package models

import (
	"cpsat-scheduler/internal/state"

	"charm.land/bubbles/v2/textinput"
	tea "charm.land/bubbletea/v2"
)

type taskFormState int

const (
	taskform_timescale taskFormState = iota
	taskform_deadline
	taskform_config_type
	taskform_duration
	taskform_children
	taskform_parent
	taskform_start_end
	taskform_prereq
)

type TaskFormRelOpts struct {
	Child    *int64
	Parent   *int64
	Prereqs  []int64
	Postreqs []int64
}

type TaskForm struct {
	rel TaskFormRelOpts

	builder state.TaskBuilder
	state   taskFormState

	ti textinput.Model
}

func NewTaskForm(builder state.TaskBuilder, rel TaskFormRelOpts) TaskForm {
	form := TaskForm{
		builder: builder,
		ti:      textinput.New(),
		state:   taskform_timescale,
	}
	form.ti.Placeholder = ""
	form.ti.SetVirtualCursor(false)
	form.ti.Focus()
	form.ti.CharLimit = 256
	form.ti.SetWidth(20)
	return form
}

func (f TaskForm) Init() tea.Cmd {
	return nil
}

func (f *TaskForm) setError(err string) {
	// TODO: implement
}

func (f TaskForm) controlFilled() bool {
	// TODO: implement
}

/**
task:
1. list input
2. time input
3. choice input -> duration | children
4. parent (list) | skip
5. start -> end (opt. range) | skip

duration
1. ask total cost (required if deadline)

*/

func (f TaskForm) Update(msg tea.Msg) (next tea.Model, cmd tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		switch msg.Code {
		case tea.KeyTab:
			if !f.controlFilled() {
				(&f).setError("required field not filled.")
				next = f
				return
			}
			if msg.Mod.Contains(tea.ModShift) {
			} else {

			}
		default:
			f.ti, cmd = f.ti.Update(msg)
		}
	default:
		f.ti, cmd = f.ti.Update(msg)
	}
	next = f
	return
}

func (f TaskForm) View() tea.View {
}
