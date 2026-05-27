use ../lib/proto/apipb/api.gen.nu

# to convert an event to tasks we discretize it in terms of the smallest timescale

let start: datetime = (date now | format date %Y-%m-%dT23:00:00 | into datetime) + 1day
let end: datetime = $start + 365day

0..(($end - $start) // 1day)
	| each {|idx|
	let st = $start + 1day * $idx
		{
			profile: 1
			name: sleep
			desc: ""
			start: $st
			end: ($st + 8hr)
		}
	}
	| wrap event
	| api.gen API CreateEvent

