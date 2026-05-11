package models

import (
	tea "charm.land/bubbletea/v2"
	"charm.land/huh/v2"
)

type focusEvent struct {
	key   string
	focus bool
}

type commonField struct {
	key           string
	focused       bool
	theme         huh.Theme
	darkBg        bool
	width, height int
}

func newCommonField(key string) commonField {
	return commonField{key: key}
}

func (f *commonField) handleUpdate(msg tea.Msg) tea.Cmd {
	switch msg := msg.(type) {
	case tea.BackgroundColorMsg:
		f.darkBg = msg.IsDark()
	case focusEvent:
		if f.key == msg.key {
			f.focused = msg.focus
		}
	case tea.KeyPressMsg:
		switch {
		case msg.Code == tea.KeyEnter && msg.Mod == 0:
			return huh.NextField
		case msg.Code == tea.KeyTab && msg.Mod == 0:
			return huh.NextField
		case msg.Code == tea.KeyTab && msg.Mod == tea.ModShift:
			return huh.PrevField
		}
	}
	return nil
}

func (f commonField) getStyles() *huh.FieldStyles {
	theme := f.theme
	if theme == nil {
		theme = huh.ThemeFunc(huh.ThemeCharm)
	}
	if f.focused {
		return &theme.Theme(f.darkBg).Focused
	}
	return &theme.Theme(f.darkBg).Blurred
}

func (f commonField) Blur() tea.Cmd {
	return func() tea.Msg {
		return focusEvent{
			key:   f.key,
			focus: false,
		}
	}
}

func (f commonField) Focus() tea.Cmd {
	return func() tea.Msg {
		return focusEvent{
			key:   f.key,
			focus: true,
		}
	}
}

func (f *commonField) handleWithTheme(th huh.Theme) {
	f.theme = th
}

func (f *commonField) handleWithWidth(width int) {
	f.width = width
}

func (f *commonField) handleWithHeight(height int) {
	f.height = height
}

func (f *commonField) GetKey() string {
	return f.key
}
