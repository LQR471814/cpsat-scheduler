package main

import (
	"fmt"
	"log"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type model struct {
	choices  []string         // items on the to-do list
	cursor   int              // which to-do list item our cursor is pointing at
	selected map[int]struct{} // which to-do items are selected
}

func newModel() model {
	return model{
		// Our to-do list is a grocery list
		choices: []string{"Buy carrots", "Buy celery", "Buy kohlrabi"},

		// A map which indicates which choices are selected. We're using
		// the  map like a mathematical set. The keys refer to the indexes
		// of the `choices` slice, above.
		selected: make(map[int]struct{}),
	}
}

func (m model) Init() tea.Cmd {
	// Just return `nil`, which means "no I/O right now, please."
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		switch msg.Code {
		case 'q':
			// quit!
			return m, tea.Quit
		case tea.KeyUp, 'k':
			if m.cursor > 0 {
				m.cursor--
			}
		case tea.KeyDown, 'j':
			if m.cursor < len(m.choices)-1 {
				m.cursor++
			}
		case tea.KeyEnter, tea.KeySpace:
			_, ok := m.selected[m.cursor]
			if ok {
				delete(m.selected, m.cursor)
			} else {
				m.selected[m.cursor] = struct{}{}
			}
		}
	}
	return m, nil
}

var titleStyle = lipgloss.NewStyle().
	Italic(true).
	Foreground(lipgloss.Color("#7D56F4")).
	PaddingBottom(1).
	Width(22)

var checkStyle = lipgloss.NewStyle().
	Bold(true).
	Foreground(lipgloss.Red)

func (m model) View() tea.View {
	s := fmt.Sprintf("%s\n", titleStyle.Render("What to buy?"))
	for i, choice := range m.choices {
		cursor := " "
		if m.cursor == i {
			cursor = checkStyle.Render(">")
		}
		checked := " "
		if _, ok := m.selected[i]; ok {
			checked = checkStyle.Render("x")
		}
		s += fmt.Sprintf("%s [%s] %s\n", cursor, checked, choice)
	}
	s += fmt.Sprintf("\n%s\n", titleStyle.Render("Q to quit."))
	return tea.NewView(s)
}

func main() {
	p := tea.NewProgram(newModel())
	if _, err := p.Run(); err != nil {
		log.Fatal(err)
	}
}
