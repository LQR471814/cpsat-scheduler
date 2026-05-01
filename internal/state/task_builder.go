package state

import "time"

type DurState struct {
	PessimisticUnit int
	Pessimistic     int

	ExpectedUnit int
	Expected     int

	OptimisticUnit int
	Optimistic     int

	Deadline  time.Time
	TotalCost int
}

type ChildrenConfigState struct {
	Desc         string
	Deadline     time.Time
	ExpectedCost int
}

type TaskState struct {
	Timescale int
	Deadline  time.Time

	DurationConfig  *DurState
	ChildrenConfigs []ChildrenConfigState
	Prerequisites   []int
	Postrequisites  []int
	Parent          *int
}

type TaskBuilder struct {
	ctx   Context
	state TaskState
}
