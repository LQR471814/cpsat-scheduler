def init []: nothing -> nothing {
	stor reset

	stor create --table-name task --columns {
		id: int
		unit: int
		start: int
		end: int

		name: str
		desc: str
	}

	stor create --table-name prereq --columns {
		prereq_id: int
		task_id: int
	}

	stor create --table-name child --columns {
		parent_task: int
		child_task: int
	}

	stor create --table-name duration --columns {
		task_id: int
		# PERT (optimistic, expected, pessimistic)
		min: int
		avg: int
		max: int
		# committed records how much time has been committed to this task already
		committed: int
	}

	stor export --file-name state.db
	open state.db # nu-lint-ignore: catch_builtin_error_try
}

# load loads the database
export def load []: nothing -> table {
	try {
		open "state.db"
	} catch {
		rm --force "state.db"
		init
	}
}

