local ok, keymap = pcall(require, "lqr471814.lib.keymap")

if ok then
	local excludes = {
		"*.spec.gen.nu"
	}
	if default_fs_exclusion ~= nil  then
		for _, value in ipairs(default_fs_exclusion) do
			table.insert(excludes, value)
		end
	end
	keymap.overwrite_map("n", "<leader>ps", function()
		Snacks.picker.grep({
			hidden = true,
			exclude = excludes,
		})
	end, "Find files via text content.")
end
