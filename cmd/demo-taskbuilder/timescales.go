package main

import "charm.land/huh/v2"

// note: these do not fully approximate actual time and will begin lagging
// behind it, thus they must be converted
const (
	minute_15 = 1
	hour_4    = 4 * 4 * minute_15
	day       = 6 * hour_4
	week      = 7 * day
	month     = 4 * week
	quarter   = 3 * month
	year      = 4 * quarter
	year_2    = 2 * year
	year_4    = 2 * year_2
	year_8    = 2 * year_4
	year_16   = 2 * year_8
	year_32   = 2 * year_16
	year_64   = 2 * year_32
	year_128  = 2 * year_64
)

func timescaleSelect() *huh.Select[int] {
	return huh.NewSelect[int]().
		Title("Timescale Unit").
		Options(
			huh.NewOption("15 minute", minute_15),
			huh.NewOption("4 hour", hour_4),
			huh.NewOption("day (24 hour)", day),
			huh.NewOption("week (7 day)", week),
			huh.NewOption("month (4 week)", month),
			huh.NewOption("quarter (3 month)", quarter),
			huh.NewOption("year (4 quarter)", year),
			huh.NewOption("2 year", year_2),
			huh.NewOption("4 year", year_4),
			huh.NewOption("8 year", year_8),
			huh.NewOption("16 year", year_16),
			huh.NewOption("32 year", year_32),
			huh.NewOption("64 year", year_64),
			huh.NewOption("128 year", year_128),
		)
}
