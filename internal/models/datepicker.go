package models

import (
	"fmt"

	tea "charm.land/bubbletea/v2"
)

type DatePicker struct {
	month, day, year UnsignedInput
}

func NewDatePicker(month, day, year *uint) DatePicker {
	return DatePicker{
		month: NewUnsignedInput(month, UnsignedInputOptions{2, 'm'}),
		day:   NewUnsignedInput(day, UnsignedInputOptions{2, 'd'}),
		year:  NewUnsignedInput(year, UnsignedInputOptions{4, 'y'}),
	}
}

func (m DatePicker) Init() tea.Cmd {
	return tea.Batch(
		m.month.Init(),
		m.day.Init(),
		m.year.Init(),
	)
}

func (m DatePicker) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		switch msg.Code {
		case tea.KeyTab:
			if msg.Mod == tea.ModShift {

			} else {

			}
		}
	}
	return m, nil
}

func (m DatePicker) View() tea.View {
	text := fmt.Sprintf(
		"%s-%s-%s",
		m.year.View().Content,
		m.month.View().Content,
		m.day.View().Content,
	)
	return tea.NewView(text)
}
