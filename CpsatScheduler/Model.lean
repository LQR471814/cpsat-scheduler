import CpsatScheduler.UnitAware

open CpsatScheduler

namespace CpsatScheduler

structure Model.Task (scales : Timescales) where
  task : Task scales
  startVar : TaskVars scales
  costTable : TaskCostTable (scales := scales) task

end CpsatScheduler
