package models

import (
	"fmt"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type DatePicker struct {
	month, day, year UnsignedInput
	err              bool
}

func NewDatePicker(month, day, year *uint) DatePicker {
	return DatePicker{
		month: NewUnsignedInput(month, UnsignedInputOptions{2, 'm'}),
		day:   NewUnsignedInput(day, UnsignedInputOptions{2, 'd'}),
		year:  NewUnsignedInput(year, UnsignedInputOptions{4, 'y'}),
	}
}

func (p DatePicker) Init() tea.Cmd {
	return tea.Batch(
		p.month.Init(),
		p.day.Init(),
		p.year.Init(),
	)
}

func (p *DatePicker) handleDelete() {
	// find the rightmost input that is not at start and delete from it
	if !p.day.Start() {
		p.day.SetFocus(true)
		p.month.SetFocus(false)
		p.year.SetFocus(false)
		p.day.Delete()
		return
	}
	if !p.month.Start() {
		p.day.SetFocus(false)
		p.month.SetFocus(true)
		p.year.SetFocus(false)
		p.month.Delete()
		return
	}
	p.day.SetFocus(false)
	p.month.SetFocus(false)
	p.year.SetFocus(true)
	p.year.Delete()
}

func (p *DatePicker) handleAppend(msg tea.KeyPressMsg) {
	// find the leftmost input that is not at end and append to it
	if !p.year.End() {
		p.year.SetFocus(true)
		p.month.SetFocus(false)
		p.day.SetFocus(false)
		p.year.Append(msg)
		return
	}
	if !p.month.End() {
		p.year.SetFocus(false)
		p.month.SetFocus(true)
		p.day.SetFocus(false)
		p.month.Append(msg)
		return
	}
	p.year.SetFocus(false)
	p.month.SetFocus(false)
	p.day.SetFocus(true)
	p.day.Append(msg)
}

func (p *DatePicker) Validate() {
	year := p.year.Value()
	month := p.month.Value()
	day := p.day.Value()

	if year == 0 || month == 0 || month > 12 || day == 0 {
		p.err = true
		return
	}

	t := time.Date(int(year), time.Month(month), int(day), 0, 0, 0, 0, time.UTC)
	p.err = t.Year() != int(year) ||
		uint(t.Month()) != month ||
		uint(t.Day()) != day
}

func (p DatePicker) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
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

var datePickerErrStyle = lipgloss.NewStyle().Foreground(lipgloss.BrightRed)

func (p DatePicker) View() tea.View {
	text := fmt.Sprintf(
		"%s-%s-%s",
		p.year.View().Content,
		p.month.View().Content,
		p.day.View().Content,
	)
	if p.err {
		text = lipgloss.JoinHorizontal(
			lipgloss.Top,
			text,
			" ",
			datePickerErrStyle.Render("!"),
		)
	}
	return tea.NewView(text)
}

func (p DatePicker) SetYear(y uint) {
	p.year.Set(y)
}

func (p DatePicker) Year() uint {
	return p.year.Value()
}

func (p DatePicker) SetMonth(m uint) {
	p.month.Set(m)
}

func (p DatePicker) Month() uint {
	return p.month.Value()
}

func (p DatePicker) SetDay(d uint) {
	p.day.Set(d)
}

func (p DatePicker) Day() uint {
	return p.day.Value()
}

func (p DatePicker) Err() bool {
	return p.err
}

type Date struct {
	Year  uint
	Month uint
	Day   uint
}
