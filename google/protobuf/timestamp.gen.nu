const SOCKET_PATH = "/tmp/cpsat-scheduler.api.sock"

const self_path = path self

export def req [api: string, method: string]: any -> any {
    let schema_path = $self_path | path dirname | path join ../../proto
	$in
        | to json --raw
        | buf curl -d @- --unix-socket $SOCKET_PATH --protocol grpc --http2-prior-knowledge --schema $schema_path $"http://localhost/($api)/($method)"
		| from json
}

def "deserialize proto dur" []: string -> duration {
	1sec * ($in | str substring 0..<(($in | str length) - 1) | into float)
}

def "deserialize proto time" []: string -> datetime {
	into datetime | date to-timezone local
}

def "serialize proto dur" []: duration -> string {
    $"($in / 1sec)s"
}

def "serialize proto time" []: datetime -> string {
    format date %+
}
