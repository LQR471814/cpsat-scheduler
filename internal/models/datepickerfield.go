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

type datePickerEvent struct {
	focus bool
}

type DatePickerFieldOption struct {
	Desc     string
	Required bool
	Skip     func() bool
}

type DatePickerField struct {
	picker DatePicker
	opts   DatePickerFieldOption
	title  string
	key    string

	focused       bool
	theme         huh.Theme
	darkBg        bool
	width, height int
}

func NewDatePickerField(
	key string,
	title string,
	month, day, year *uint,
	opts DatePickerFieldOption,
) *DatePickerField {
	return &DatePickerField{
		picker: NewDatePicker(month, day, year),
		title:  title,
		key:    key,
		opts:   opts,
	}
}

func (p *DatePickerField) Init() tea.Cmd {
	return p.picker.Init()
}

func (p *DatePickerField) Update(msg tea.Msg) (huh.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.BackgroundColorMsg:
		p.darkBg = msg.IsDark()
		return p, nil
	case datePickerEvent:
		p.focused = msg.focus
		return p, nil
	case tea.KeyPressMsg:
		switch {
		case msg.Code == tea.KeyTab && msg.Mod == 0:
			return p, huh.NextField
		case msg.Code == tea.KeyTab && msg.Mod == tea.ModShift:
			return p, huh.PrevField
		}
	}
	updated, cmd := p.picker.Update(msg)
	p.picker = updated.(DatePicker)
	return p, cmd
}

func (p *DatePickerField) getStyles() *huh.FieldStyles {
	theme := p.theme
	if theme == nil {
		theme = huh.ThemeFunc(huh.ThemeCharm)
	}
	if p.focused {
		return &theme.Theme(p.darkBg).Focused
	}
	return &theme.Theme(p.darkBg).Blurred
}

func (p *DatePickerField) View() string {
	styles := p.getStyles()
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
	return baseStyle.Width(p.width).Height(p.height).Render(joined)
}

// Bubble Tea Events
func (p *DatePickerField) Blur() tea.Cmd {
	return func() tea.Msg {
		return datePickerEvent{
			focus: false,
		}
	}
}

func (p *DatePickerField) Focus() tea.Cmd {
	return func() tea.Msg {
		return datePickerEvent{
			focus: true,
		}
	}
}

// Errors and Validation
func (p *DatePickerField) Error() error {
	if p.picker.err {
		return fmt.Errorf("invalid date")
	}
	return nil
}

// Run runs the field individually.
func (p *DatePickerField) Run() error {
	// TODO: figure out what to do here???
	return nil
}

// RunAccessible runs the field in accessible mode with the given IO.
func (p *DatePickerField) RunAccessible(w io.Writer, r io.Reader) (err error) {
	rd := bufio.NewReader(r)

	fmt.Fprintln(w, "Year:")
	value, err := rd.ReadString('\n')
	if err != nil {
		return
	}
	year, err := strconv.ParseUint(value, 10, 32)
	if err != nil {
		return
	}
	*p.picker.year.value = uint(year)

	fmt.Fprintln(w, "Month:")
	value, err = rd.ReadString('\n')
	if err != nil {
		return
	}
	month, err := strconv.ParseUint(value, 10, 32)
	if err != nil {
		return
	}
	*p.picker.month.value = uint(month)

	fmt.Fprintln(w, "Day:")
	value, err = rd.ReadString('\n')
	if err != nil {
		return
	}
	day, err := strconv.ParseUint(value, 10, 32)
	if err != nil {
		return
	}
	*p.picker.day.value = uint(day)

	p.picker.validate()
	return
}

// Skip returns whether this input should be skipped or not.
func (p *DatePickerField) Skip() bool {
	if p.opts.Skip != nil {
		return p.opts.Skip()
	}
	return false
}

// Zoom returns whether this input should be zoomed or not.
// Zoom allows the field to take focus of the group / form height.
func (p *DatePickerField) Zoom() bool {
	return false
}

// KeyBinds returns help keybindings.
func (p *DatePickerField) KeyBinds() []key.Binding {
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
func (p *DatePickerField) WithTheme(th huh.Theme) huh.Field {
	p.theme = th
	return p
}

// WithKeyMap sets the keymap on a field.
func (p *DatePickerField) WithKeyMap(km *huh.KeyMap) huh.Field {
	return p
}

// WithWidth sets the width of a field.
func (p *DatePickerField) WithWidth(width int) huh.Field {
	p.width = width
	return p
}

// WithHeight sets the height of a field.
func (p *DatePickerField) WithHeight(height int) huh.Field {
	p.height = height
	return p
}

// WithPosition tells the field the index of the group and position it is in.
func (p *DatePickerField) WithPosition(huh.FieldPosition) huh.Field {
	// TODO: implement
	return p
}

// GetKey returns the field's key.
func (p *DatePickerField) GetKey() string {
	return p.key
}

// GetValue returns the field's value.
func (p *DatePickerField) GetValue() any {
	return Date{
		Year:  p.picker.year.Value(),
		Month: p.picker.month.Value(),
		Day:   p.picker.day.Value(),
	}
}
