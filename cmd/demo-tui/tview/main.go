package main

import (
	"strings"

	"github.com/gdamore/tcell/v2"
	"github.com/rivo/tview"
)

func main() {
	bg := tcell.NewRGBColor(0, 0, 0)
	tview.Styles.PrimitiveBackgroundColor = bg
	tview.Styles.ContrastBackgroundColor = bg
	tview.Styles.MoreContrastBackgroundColor = bg

	flex := tview.NewFlex()

	list := tview.NewList()
	list.SetBorder(true).SetTitle("List")
	list.AddItem("apples", "apples are great", 'a', func() {})
	list.AddItem("oranges", "oranges also great", 'o', func() {})

	flex.AddItem(list, 0, 1, true)

	input := tview.NewInputField()
	input.SetBorder(true).SetTitle("Input.")
	listEntries := []string{
		"Apple",
		"Orange",
		"Grape",
	}
	input.SetAutocompleteFunc(func(currentText string) (entries []string) {
		var filtered []string
		for _, e := range listEntries {
			if strings.HasPrefix(strings.ToLower(e), strings.ToLower(currentText)) {
				filtered = append(filtered, e)
			}
		}
		return filtered
	})

	flex.AddItem(input, 0, 1, true)

	focusState := false
	app := tview.NewApplication()
	app.SetInputCapture(func(event *tcell.EventKey) *tcell.EventKey {
		switch event.Key() {
		case tcell.KeyTab:
			if !focusState {
				app.SetFocus(list)
			} else {
				app.SetFocus(input)
			}
			focusState = !focusState
			return nil
		}
		return event
	})

	if err := app.SetRoot(flex, true).Run(); err != nil {
		panic(err)
	}
}
