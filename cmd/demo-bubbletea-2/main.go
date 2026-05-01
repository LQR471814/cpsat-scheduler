package main

import (
	"fmt"
	"image/color"
	"log"
	"math/rand"
	"time"

	"charm.land/bubbles/v2/spinner"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

func checkServer() tea.Msg {
	time.Sleep(2 * time.Second)
	if rand.Int()%2 == 0 {
		return errMsg{
			err: fmt.Errorf("error occurred!"),
		}
	}
	return resMsg{
		status: 999,
	}
}

type errMsg struct {
	err error
}

type resMsg struct {
	status int
}

type model struct {
	err     error
	status  int
	spinner spinner.Model
	sending bool
}

func newModel() model {
	s := spinner.New()
	s.Spinner = spinner.Jump
	s.Style = lipgloss.NewStyle().Foreground(color.White)
	return model{
		spinner: s,
		sending: true,
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		checkServer,
		m.spinner.Tick,
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	switch msg := msg.(type) {
	case errMsg:
		m.sending = false
		m.err = msg.err
		m.status = -1
		log.Println("recv error")
	case resMsg:
		m.sending = false
		m.err = nil
		m.status = msg.status
		log.Println("recv res")
	case tea.KeyPressMsg:
		switch msg.Code {
		case 'r':
			if !m.sending {
				m.sending = true
				return m, tea.Batch(checkServer, m.spinner.Tick)
			}
		case 'q':
			return m, tea.Quit
		default:
			return m, nil
		}
	}
	log.Println(m.sending)
	if m.sending {
		m.spinner, cmd = m.spinner.Update(msg)
	}
	return m, cmd
}

var statStyle = lipgloss.NewStyle().Foreground(lipgloss.Blue)
var errStyle = lipgloss.NewStyle().Italic(true).Foreground(lipgloss.Red)

func (m model) View() tea.View {
	if m.sending {
		text := fmt.Sprintf("Loading %s q to quit...\n", m.spinner.View())
		return tea.NewView(text)
	}
	if m.err != nil {
		text := fmt.Sprintf("Error: %s\n", errStyle.Render(m.err.Error()))
		return tea.NewView(text)
	}
	text := fmt.Sprintf("Status: %s", statStyle.Render(fmt.Sprint(m.status)))
	return tea.NewView(text)
}

func main() {
	f, err := tea.LogToFile("debug.log", "debug")
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	if _, err := tea.NewProgram(newModel()).Run(); err != nil {
		log.Fatal(err)
	}
}
