# @input nothing
# @output int
export def --env read []: nothing -> int {
  $env.profile
}

# @input int
# @output nothing
export def --env write []: int -> nothing {
  $env.profile = $in
}
