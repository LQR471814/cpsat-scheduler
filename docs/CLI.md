1. method to create task (list of preset constants)
2. method to edit / delete task
3. methods to view:
    1. method to view current timescale instance of a given unit in current schedule
    2. method to view child timescale instances of a given timescale
4. method to sync events from caldav
5. schedule recomputation should happen automatically

All workflows should have a "cancel" and "cancel + save" option at
any time.

# Cost management

Best to ensure explicit direct relationship exists between all
task costs.

Best to do this with a "unit" system.

The user simply has to ensure that any unit can be transformed
into any other unit.

# Create / edit task

Parameters:

- One of: (child task) or (parent task) or (none)
- List of postrequisite tasks
- List of prerequisite tasks
- Existing task if editing task.

1. Ask: Task timescale
    - If parent task, only smaller than parent.
    - If child task, only larger than child.
2. Ask: Deadline (or none)
    - If parent, limited by parent deadline (if exist)
    - Limit by prerequisite and postrequisite deadline (if exist)
3. Ask: Duration or children
4. If duration:
    1. Ask: Total cost of non-completion. (if deadline)
    2. Ask: PERT duration (with explicit units) View: resulting
    cost configurations.
5. If children:
    1. View: List of cost configuration + current selected. (One
    cost configuration created by default.)
    2. If deadline:
        1. Ask: Total cost of current configuration
        2. Ask: Probability of cost configuration
    3. Choose:
        - Action: New child task under current cost configuration,
          should redirect to [[#Create / edit task]] flow with
          parent task set to the current ask.
        - Action: New cost configuration (disabled if no child
          present)
6. Ask: Optional constraints
    1. Ask: Parent
    2. Ask: Explicit start/end time restrictions.
    3. Ask/Choose: Prerequisites.
        - Action: Select from tasks in the same timescale
        - Action: Option to create new prerequisite, redirect to
          [[#Create / edit task]] with postrequisite as the
          self.
        - Action: Option to create a new postrequisite, redirect
          to [[#Create / edit task]] with prerequisite as the
          self.
    4. Error if: Explicit start != null && prerequisite after
    explicit start

# Progress update

1. Ask: Which gap in time to fill in. (if any), can skip
    1. For a given gap $g$.
    2. Select a region of $g$ to allocate to a particular task
       $t$ or to create a new task which will redirect to [[#Create / edit task]].
    3. Repeat until -> "done" or "cancel".

# Today

Should be able to see:

- Tasks for today
    - Should be able to select tasks
- Already allocated time (from [[#Progress update]])
- Fixed time events

# Multi-day

Should be able to see:

- Tasks scheduled on multiple days within a span of time.
- Should be able to select tasks

# Calendar Integration

- Calendar events should automatically sync to fixed tasks.
- Progress updates for events should happen automatically.

