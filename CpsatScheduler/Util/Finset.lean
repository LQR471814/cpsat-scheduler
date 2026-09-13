import Mathlib.Data.Finset.Sort
import Mathlib.Data.String.Basic

def Finset.sortByKey
    {α : Type}
    [DecidableEq α]
    (set : Finset α)
    (key : set → String)
    (key_injective : Function.Injective key) :
    List set :=
  have nameOf_injective : Function.Injective key :=
    fun a b h =>
      key_injective h

  letI : LinearOrder set :=
    LinearOrder.lift' key nameOf_injective

  set.attach.sort
