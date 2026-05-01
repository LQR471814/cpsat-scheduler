1. method to create task (list of preset constants)
2. method to edit / delete task
3. methods to view:
    1. method to view current timescale instance of a given unit in current schedule
    2. method to view child timescale instances of a given timescale
4. method to sync events from caldav
5. schedule recomputation should happen automatically

# Cost management

Best to ensure explicit direct relationship exists between all
task costs.

Best to do this with a "unit" system.

The user simply has to ensure that any unit can be transformed
into any other unit.

# Creation Workflows

All workflows should have a "cancel" and "cancel + save" option at
any time.

## Create task w/ hard deadline

1. Ask: Task timescale
2. Ask: Deadline
3. Ask: Total cost of non-completion.
4. Ask: Duration or children
5. If duration:
    - Ask: PERT duration (with explicit units) View: resulting
      cost configurations.
6. If children:
    - View: List of cost configuration + current selected.
    - Exec: One cost configuration created by default.
    - Actions:
        - Action: New child task under current cost configuration,
          should redirect to [[#Create child]] flow.
        - Action: New cost configuration (disabled if no child
          present)
7. Ask: Optional constraints
    - Ask: Parent
    - Ask: Explicit start/end time restrictions.
    - Ask: Prerequisites.
        - Action: Select from tasks in the same timescale
        - Action: Option to create new prerequisite, redirect to
          [[#Create prerequisite]].
    - Error if: Explicit start != null && prerequisite after
      explicit start

## Create task w/ soft deadline

1. Ask: Task timescale
2. Ask:

## Create child

## Create parent

## Create prerequisite

## Create from prerequisite

