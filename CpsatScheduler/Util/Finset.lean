import Mathlib.Data.Finset.Sort
import Mathlib.Data.String.Basic

def Finset.sortByKey
  {α β : Type} [DecidableEq α] [LinearOrder β]
  (set : Finset α)
  (key : set → β)
  (key_injective : Function.Injective key) :
    List set :=
  have nameOf_injective : Function.Injective key :=
    fun a b h =>
      key_injective h
  letI : LinearOrder set :=
    LinearOrder.lift' key nameOf_injective
  set.attach.sort

