package models

import (
	tea "charm.land/bubbletea/v2"

	"charm.land/lipgloss/v2"
)

type TimePicker struct {
	hour   UnsignedInput
	minute UnsignedInput
	err    bool
}

func NewTimePicker(hour, minute *uint) TimePicker {
	if *hour >= 24 {
		panic("assert: hour cannot >= 24")
	}
	if *minute >= 60 {
		panic("assert: minute cannot >= 60")
	}
	picker := TimePicker{
		hour:   NewUnsignedInput(hour, UnsignedInputOptions{2, '0'}),
		minute: NewUnsignedInput(minute, UnsignedInputOptions{2, '0'}),
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

func (p *TimePicker) Validate() {
	p.err = p.hour.Value() >= 24 || p.minute.Value() >= 60
}

func (p TimePicker) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		if msg.Code >= '0' && msg.Code <= '9' {
			p.handleAppend(msg)
		}
		if msg.Code == tea.KeyBackspace {
			p.handleDelete()
		}
	}
	p.Validate()
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

func (p TimePicker) Err() bool {
	return p.err
}

func (p TimePicker) SetHour(hour uint) {
	p.hour.Set(hour)
}

func (p TimePicker) Hour() uint {
	return p.hour.Value()
}

func (p TimePicker) SetMinute(minute uint) {
	p.minute.Set(minute)
}

func (p TimePicker) Minute() uint {
	return p.minute.Value()
}

type Time struct {
	Hour   uint
	Minute uint
}
