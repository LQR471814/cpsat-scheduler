import CpsatScheduler.Defs

open CpsatScheduler

namespace CpsatScheduler

structure Model.Task (scales : Timescales) where
  task : Task scales
  startVar : TaskStart scales
  costTable : TaskCostTable (scales := scales) task

end CpsatScheduler
