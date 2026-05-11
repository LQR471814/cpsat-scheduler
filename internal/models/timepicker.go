package models

import (
	"fmt"
	"io"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"
	"charm.land/huh/v2"
	"charm.land/lipgloss/v2"
)

type timePickerEvent struct {
	focus bool
}

type TimePicker struct {
	hour    UnsignedInput
	minute  UnsignedInput
	err     bool
	focused bool
}

func NewTimePicker(hour, minute uint) TimePicker {
	if hour < 0 {
		panic("assert: hour cannot < 0")
	}
	if minute < 0 {
		panic("assert: minute cannot < 0")
	}
	if hour >= 24 {
		panic("assert: hour cannot >= 24")
	}
	if minute >= 60 {
		panic("assert: minute cannot >= 60")
	}
	picker := TimePicker{
		hour:   NewUnsignedInput(hour, 2, '0'),
		minute: NewUnsignedInput(minute, 2, '0'),
	}
	return picker
}

func (p TimePicker) Init() tea.Cmd {
	return tea.Batch(
		p.hour.Init(),
		p.minute.Init(),
	)
}

func (p *TimePicker) handleDelete() {
	if p.minute.Start() {
		p.hour.SetFocus(true)
		p.minute.SetFocus(false)
		p.hour.Delete()
		return
	}
	p.hour.SetFocus(false)
	p.minute.SetFocus(true)
	p.minute.Delete()
}

func (p *TimePicker) handleAppend(msg tea.KeyPressMsg) {
	if p.hour.End() {
		p.hour.SetFocus(false)
		p.minute.SetFocus(true)
		p.minute.Append(msg)
		return
	}
	p.hour.SetFocus(true)
	p.minute.SetFocus(false)
	p.hour.Append(msg)
}

func (p TimePicker) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case timePickerEvent:
		p.focused = msg.focus
	case tea.KeyPressMsg:
		if msg.Code >= '0' && msg.Code <= '9' {
			p.handleAppend(msg)
		}
		if msg.Code == tea.KeyBackspace {
			p.handleDelete()
		}
	}
	p.err = p.hour.Value() >= 24 || p.minute.Value() >= 60
	return p, nil
}

var errStyle = lipgloss.NewStyle().Foreground(lipgloss.BrightRed)

func (p TimePicker) View() tea.View {
	text := lipgloss.JoinHorizontal(
		lipgloss.Top,
		p.hour.View().Content,
		":",
		p.minute.View().Content,
	)
	if p.err {
		text = lipgloss.JoinHorizontal(
			lipgloss.Top,
			text,
			" ",
			errStyle.Render("!"),
		)
	}
	return tea.NewView(text)
}

func (p TimePicker) Hour() uint {
	return p.hour.Value()
}

func (p TimePicker) Minute() uint {
	return p.minute.Value()
}

// Bubble Tea Events
func (p TimePicker) Blur() tea.Cmd {
	return func() tea.Msg {
		return timePickerEvent{
			focus: false,
		}
	}
}
func (p TimePicker) Focus() tea.Cmd {
	return func() tea.Msg {
		return timePickerEvent{
			focus: true,
		}
	}
}

// Errors and Validation
func (p TimePicker) Error() error {
	if p.err {
		return fmt.Errorf("invalid time")
	}
	return nil
}

// Run runs the field individually.
func (p TimePicker) Run() error {
	return huh.Run(p)
}

// RunAccessible runs the field in accessible mode with the given IO.
func (p TimePicker) RunAccessible(w io.Writer, r io.Reader) error {}

// Skip returns whether this input should be skipped or not.
func (p TimePicker) Skip() bool {
	return
}

// Zoom returns whether this input should be zoomed or not.
// Zoom allows the field to take focus of the group / form height.
func (p TimePicker) Zoom() bool {}

// KeyBinds returns help keybindings.
func (p TimePicker) KeyBinds() []key.Binding {}

// WithTheme sets the theme on a field.
func (p TimePicker) WithTheme(huh.Theme) huh.Field {}

// WithKeyMap sets the keymap on a field.
func (p TimePicker) WithKeyMap(*huh.KeyMap) huh.Field {}

// WithWidth sets the width of a field.
func (p TimePicker) WithWidth(int) huh.Field {}

// WithHeight sets the height of a field.
func (p TimePicker) WithHeight(int) huh.Field {}

// WithPosition tells the field the index of the group and position it is in.
func (p TimePicker) WithPosition(huh.FieldPosition) huh.Field {}

// GetKey returns the field's key.
func (p TimePicker) GetKey() string {}

// GetValue returns the field's value.
func (p TimePicker) GetValue() any {}
