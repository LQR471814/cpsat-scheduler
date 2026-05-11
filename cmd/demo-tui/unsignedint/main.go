package main

import (
	"cpsat-scheduler/internal/models"
	"fmt"
	"os"

	tea "charm.land/bubbletea/v2"
)

type testModel struct {
	inner tea.Model
}

func (m testModel) Init() tea.Cmd {
	return m.inner.Init()
}

func (m testModel) Update(msg tea.Msg) (out tea.Model, cmd tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		switch msg.Code {
		case 'q':
			return m, tea.Quit
		}
	}
	m.inner, cmd = m.inner.Update(msg)
	out = m
	return
}

func (m testModel) View() tea.View {
	return m.inner.View()
}

func main() {
	f, err := tea.LogToFile("debug.log", "debug")
	if err != nil {
		fmt.Println("fatal:", err)
		os.Exit(1)
	}
	defer f.Close()

	var hour uint
	input := models.NewUnsignedInput(&hour, models.UnsignedInputOptions{
		MaxDigits:   4,
		Placeholder: 'd',
	})
	model := testModel{inner: input}

	program := tea.NewProgram(model)
	_, err = program.Run()
	if err != nil {
		return
	}

	fmt.Println(hour)
}
