package main

import (
	"cpsat-scheduler/internal/models"
	"fmt"
	"log"
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
	log.Println(msg)
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

	input := models.NewTimePicker(0, 0)
	model := testModel{inner: input}

	program := tea.NewProgram(model)
	_, err = program.Run()
	if err != nil {
		return
	}
}
