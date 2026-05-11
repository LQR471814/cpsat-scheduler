package models

import (
	"strconv"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type UnsignedInput struct {
	value       uint
	cursor      uint
	maxDigits   uint
	placeholder rune
	focused     bool
}

func NewUnsignedInput(value, maxDigits uint, placeholder rune) UnsignedInput {
	return UnsignedInput{
		value:       value,
		maxDigits:   maxDigits,
		placeholder: placeholder,
	}
}

func (n UnsignedInput) Init() tea.Cmd {
	return nil
}

// Start returns if the input has reached the start (no input)
func (n UnsignedInput) Start() bool {
	return n.cursor == 0
}

// End returns if the input has reached the end (max size)
func (n UnsignedInput) End() bool {
	return n.cursor >= n.maxDigits
}

func (n UnsignedInput) Value() uint {
	return n.value
}

func (n *UnsignedInput) Append(msg tea.KeyPressMsg) {
	if n.cursor >= n.maxDigits {
		return
	}
	n.value *= 10
	n.value += uint(msg.Code - '0')
	n.cursor++
}

func (n *UnsignedInput) Delete() {
	if n.cursor <= 0 {
		return
	}
	n.value /= 10
	n.cursor--
}

func (n *UnsignedInput) Set(value uint) {
	n.value = value
}

func (n UnsignedInput) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		if msg.Mod != 0 {
			return n, nil
		}
		if msg.Code >= '0' && msg.Code <= '9' {
			(&n).Append(msg)
			return n, nil
		}
		if msg.Code == tea.KeyBackspace {
			n.Delete()
			return n, nil
		}
	}
	return n, nil
}

var highlightStyle = lipgloss.NewStyle().Underline(true)

// var focusedStyle = lipgloss.NewStyle().Background(lipgloss.Color("#EB4268"))

func (n UnsignedInput) View() tea.View {
	text := strconv.FormatUint(uint64(n.value), 10)
	text = strings.Repeat(string(n.placeholder), int(n.maxDigits)-len(text)) + text

	if len(text) != int(n.maxDigits) {
		panic("assert: len(text) != int(n.maxDigits)")
	}
	if n.cursor > n.maxDigits {
		panic("assert: n.cursor > n.maxDigits")
	}

	// we know:
	// - len(text) = maxDigits
	// - cursor <= maxDigits
	// thus:
	// - valid idx for text is [0, len(text)-1]
	// - cursor can = len(text)
	// - must add guard

	// we start typing from the right edge so cursor must be computed from the
	// right
	cursorIdx := len(text) - int(n.cursor) - 1
	if cursorIdx >= 0 && n.focused {
		highlighted := text[:cursorIdx] +
			highlightStyle.Render(string(text[cursorIdx]))
		if cursorIdx+1 < len(text) {
			highlighted += text[cursorIdx+1:]
		}
		text = highlighted
	}

	// if n.focused {
	// 	text = focusedStyle.Render(text)
	// }

	return tea.NewView(text)
}

func (n *UnsignedInput) SetFocus(focused bool) {
	n.focused = focused
}
