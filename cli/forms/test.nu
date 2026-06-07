# @usetype "./lib/types.nu"

use ./lib/form.nu

# @types.Form
let value = nu ./profiles.spec.nu | from nuon

$value | form render | save out.nu -f

