# exec form executes a form script with the given env vars, it
# automatically handles output capture and response parsing
export def "exec form" [script: path params: any]: nothing -> any {
  # nu-lint-ignore: missing_output_type, add_type_hints_arguments
  do {
    let id = random chars --length 8
    load-env {
      p_in: $"/tmp/cpsat-cli.form-state.in.($id)"
      p_out: $"/tmp/cpsat-cli.form-state.out.($id)"
    }
    $params | to nuon | save $env.p_in # nu-lint-ignore: catch_builtin_error_try
    nu -e $"source '($script)'"
    let res = open $env.p_out | from nuon # nu-lint-ignore: catch_builtin_error_try
    try {
      rm $env.p_in
      rm $env.p_out
    }
    $res
  }
}

# get form params gets the input parameters of a form
export def "get form params" []: nothing -> any {
  # nu-lint-ignore: missing_output_type
  open $env.p_in | from nuon # nu-lint-ignore: catch_builtin_error_try
}

# save form output saves the output of a form into the output file
export def "save form output" []: any -> nothing {
  to nuon | save $env.p_out # nu-lint-ignore: catch_builtin_error_try
}
