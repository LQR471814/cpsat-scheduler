package models

import (
	"bufio"
	"fmt"
	"io"
	"strconv"

	"charm.land/bubbles/v2/key"
	tea "charm.land/bubbletea/v2"
	"charm.land/huh/v2"
	"charm.land/lipgloss/v2"
)

type TimePickerFieldOption struct {
	Desc     string
	Required bool
	Skip     func() bool
}

type TimePickerField struct {
	picker TimePicker
	opts   TimePickerFieldOption
	title  string
	key    string
	common commonField
}

func NewTimePickerField(
	key string,
	title string,
	hour, minute *uint,
	opts TimePickerFieldOption,
) *TimePickerField {
	return &TimePickerField{
		picker: NewTimePicker(hour, minute),
		title:  title,
		key:    key,
		opts:   opts,
		common: newCommonField(key),
	}
}

func (p *TimePickerField) Init() tea.Cmd {
	return p.picker.Init()
}

func (p *TimePickerField) Update(msg tea.Msg) (huh.Model, tea.Cmd) {
	cmd := p.common.handleUpdate(msg)
	if cmd != nil {
		return p, cmd
	}
	updated, cmd := p.picker.Update(msg)
	p.picker = updated.(TimePicker)
	return p, cmd
}

func (p *TimePickerField) View() string {
	styles := p.common.getStyles()
	baseStyle := styles.Base
	titleStyle := styles.Title
	descStyle := styles.Description
	textinputStyle := styles.TextInput.Text

	title := titleStyle.Render(p.title)
	content := textinputStyle.Render(p.picker.View().Content)

	var joined string
	if p.opts.Desc != "" {
		joined = lipgloss.JoinVertical(
			lipgloss.Left,
			title,
			descStyle.Render(p.opts.Desc),
			content,
		)
	} else {
		joined = lipgloss.JoinVertical(
			lipgloss.Left,
			title,
			content,
		)
	}
	out := baseStyle.Width(p.common.width).Height(p.common.height).Render(joined)
	return out
}

// Bubble Tea Events
func (p *TimePickerField) Blur() tea.Cmd {
	return p.common.Blur()
}
func (p *TimePickerField) Focus() tea.Cmd {
	return p.common.Focus()
}

// Errors and Validation
func (p *TimePickerField) Error() error {
	if p.picker.err {
		return fmt.Errorf("invalid time")
	}
	return nil
}

// Run runs the field individually.
func (p *TimePickerField) Run() error {
	// TODO: figure out what to do here???
	return nil
}

// RunAccessible runs the field in accessible mode with the given IO.
func (p *TimePickerField) RunAccessible(w io.Writer, r io.Reader) (err error) {
	fmt.Fprintln(w, "Hour:")
	rd := bufio.NewReader(r)
	value, err := rd.ReadString('\n')
	if err != nil {
		return
	}
	hour, err := strconv.ParseUint(value, 10, 32)
	if err != nil {
		return
	}
	*p.picker.hour.value = uint(hour)

	fmt.Fprintln(w, "Minute:")
	value, err = rd.ReadString('\n')
	if err != nil {
		return
	}
	minute, err := strconv.ParseUint(value, 10, 32)
	if err != nil {
		return
	}
	*p.picker.minute.value = uint(minute)
	return
}

// Skip returns whether this input should be skipped or not.
func (p *TimePickerField) Skip() bool {
	if p.opts.Skip != nil {
		return p.opts.Skip()
	}
	return false
}

// Zoom returns whether this input should be zoomed or not.
// Zoom allows the field to take focus of the group / form height.
func (p *TimePickerField) Zoom() bool {
	return false
}

// KeyBinds returns help keybindings.
func (p *TimePickerField) KeyBinds() []key.Binding {
	return []key.Binding{
		key.NewBinding(
			key.WithKeys("0-9"),
			key.WithHelp("0-9", "input"),
			key.WithKeys("backspace"),
			key.WithHelp("backspace", "delete"),
		),
	}
}

// WithTheme sets the theme on a field.
func (p *TimePickerField) WithTheme(th huh.Theme) huh.Field {
	p.common.handleWithTheme(th)
	return p
}

// WithKeyMap sets the keymap on a field.
func (p *TimePickerField) WithKeyMap(km *huh.KeyMap) huh.Field {
	return p
}

// WithWidth sets the width of a field.
func (p *TimePickerField) WithWidth(width int) huh.Field {
	p.common.handleWithWidth(width)
	return p
}

// WithHeight sets the height of a field.
func (p *TimePickerField) WithHeight(height int) huh.Field {
	p.common.handleWithHeight(height)
	return p
}

// WithPosition tells the field the index of the group and position it is in.
func (p *TimePickerField) WithPosition(huh.FieldPosition) huh.Field {
	// TODO: implement
	return p
}

// GetKey returns the field's key.
func (p *TimePickerField) GetKey() string {
	return p.key
}

// GetValue returns the field's value.
func (p *TimePickerField) GetValue() any {
	return Time{
		Hour:   p.picker.hour.Value(),
		Minute: p.picker.minute.Value(),
	}
}
