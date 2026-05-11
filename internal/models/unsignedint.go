package models

import (
	"strconv"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type UnsignedInputOptions struct {
	// MaxDigits specifies the maximum number of digits to input, default 2
	MaxDigits uint
	// Placeholder specifies the placeholder character, default '0'
	Placeholder rune
}

type UnsignedInput struct {
	value   *uint
	cursor  uint
	focused bool
	opts    UnsignedInputOptions
}

func NewUnsignedInput(value *uint, opts UnsignedInputOptions) UnsignedInput {
	if opts.MaxDigits == 0 {
		opts.MaxDigits = 2
	}
	if opts.Placeholder == 0 {
		opts.Placeholder = '0'
	}
	return UnsignedInput{
		value: value,
		opts:  opts,
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
	return n.cursor >= n.opts.MaxDigits
}

func (n *UnsignedInput) Append(msg tea.KeyPressMsg) {
	if n.cursor >= n.opts.MaxDigits {
		return
	}
	*n.value *= 10
	*n.value += uint(msg.Code - '0')
	n.cursor++
}

func (n *UnsignedInput) Delete() {
	if n.cursor <= 0 {
		return
	}
	*n.value /= 10
	n.cursor--
}

func (n UnsignedInput) Value() uint {
	return *n.value
}

func (n UnsignedInput) Set(value uint) {
	*n.value = value
}

func (n UnsignedInput) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		if msg.Mod != 0 {
			return n, nil
		}
		if msg.Code >= '0' && msg.Code <= '9' {
			n.Append(msg)
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
	text := strconv.FormatUint(uint64(*n.value), 10)[:n.cursor]

	text = strings.Repeat(
		string(n.opts.Placeholder),
		int(n.opts.MaxDigits)-len(text),
	) + text

	if len(text) != int(n.opts.MaxDigits) {
		panic("assert: len(text) != int(n.opts.MaxDigits)")
	}
	if n.cursor > n.opts.MaxDigits {
		panic("assert: n.cursor > n.opts.MaxDigits")
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
