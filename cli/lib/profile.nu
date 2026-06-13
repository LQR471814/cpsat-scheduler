# @input nothing
# @output int
export def --env read []: nothing -> int {
  let val = $env.cpsat-profile
  match ($val | describe) {
    string => { $val | into int }
    int => { $val }
    _ => {
      error make {
        msg: "unsupported env var type for profile"
        label: {
          text: value
          span: (metadata $val).span
        }
      }
    }
  }
}

# @input int
# @output nothing
export def --env write []: int -> nothing {
  $env.cpsat-profile = $in
}
