import CpsatScheduler.Python.Basic

namespace Python

structure Runtime where
  path : String

private def daemonFrontmatter : Array Statement := #[
  -- import sys
  .importLine (Import.basicForm #[StdName.sys] none),
]

private def daemonRuntime : Array Statement :=
  let chars := ValidName.of "__chars"
  let c := ValidName.of "__c"
  let code := ValidName.of "__code"
  #[
    .exprLine (print (.lit (.str "init"))),
    -- chars = []
    .assignLine (.id chars) (.lit (.array #[])),
    -- while True:
    .whileLine (.lit (.bool true))
      #[
        -- del chars[:]
        .delLine (.index (.id chars) (.slice .none .none)),
        -- c = None
        .assignLine (.id c) (.lit .none),
        .whileLine (.lit (.bool true))
          #[
            -- c = sys.stdin.read(1)
            .assignLine (.id c) (.call
              (.dot (.dot (.id StdName.sys) StdName.stdin) StdName.read)
              #[ .lit (.int 1) ]
              #[]),
            -- if c == '\0':
            --   break
            .ifLine {
              cond := .eq (.id c) (.lit (.str "\\0"))
              body := #[ .breakLine ]
              next := .none
            },
            -- chars.append(c)
            (.exprLine (.call
              (.dot (.id chars) StdName.append)
              #[ .id c ] #[]))
          ],
        -- exec("".join(chars))
        .exprLine
          (.call (.id StdName.exec)
            #[ .call (.dot (.lit (.str "")) StdName.join)
              #[ .id chars ] #[] ] #[])
      ]
  ]

def DaemonProcess.stdioConfig : IO.Process.StdioConfig :=
  {
    stdin := .piped
    stdout := .piped
    stderr := .inherit
  }

structure DaemonProcess where
  child : IO.Process.Child DaemonProcess.stdioConfig

def DaemonProcess.spawn (r : Runtime) (init : Array Statement) :
    IO DaemonProcess := do
  let script : Script := {
    statements := daemonFrontmatter ++ init ++ daemonRuntime
  }
  let child : IO.Process.Child DaemonProcess.stdioConfig ←
    IO.FS.withTempFile fun tempFile tempPath => do
      tempFile.write script.repr.toByteArray
      tempFile.flush
      let child ← IO.Process.spawn {
        cmd := r.path
        args := #[ tempPath.toString ]
        stdin := DaemonProcess.stdioConfig.stdin
        stdout := DaemonProcess.stdioConfig.stdout
        stderr := DaemonProcess.stdioConfig.stderr
      };
      -- wait for child to finish reading file & initializing
      -- before we can delete tmp init script
      let _ ← child.stdout.getLine
      pure child
  pure ⟨child⟩

def DaemonProcess.exec (proc : DaemonProcess)
  (script : Python.Script) :
    IO Unit := do
  proc.child.stdin.putStr s!"{script.repr}\x00"
  proc.child.stdin.flush
  pure ()

def DaemonProcess.execWithOutput (proc : DaemonProcess)
  (script : Python.Script) :
    IO String := do
  proc.exec script
  proc.child.stdout.getLine

def DaemonProcess.execWithJson (proc : DaemonProcess)
  (script : Python.Script) :
    IO (Except String Lean.Json) := do
  let output <- proc.execWithOutput script
  pure (match output with
    | "" => Except.error "got EOF"
    | _ => Lean.Json.parse output
      |> .mapError (s!"Lean.Json.parse ('{output}'): {·}"))

end Python

