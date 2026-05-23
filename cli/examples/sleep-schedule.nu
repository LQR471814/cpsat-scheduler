use ../lib/api.gen.nu

# to convert an event to tasks we discretize it in terms of the smallest timescale

let start: datetime = (date now) + 1day
let end: datetime = $start + 365day

0..(($end - $start) // 1day) | each {|idx|
	{
		event: {
			profile: 1
			name: sleep
			desc: ""
			start: ($start + 1day * $idx)
			end: ($start + 1day * ($idx + 1))
		}
	} | api.gen API CreateEvent
}

