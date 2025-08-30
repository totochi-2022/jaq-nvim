vim.cmd [[
	function! JaqCompletion(lead, cmd, cursor)
		let valid_args = [ 'internal', 'float', 'terminal', 'bang', 'quickfix' ]
		let l = len(a:lead) - 1
		if l >= 0
			let filtered_args = copy(valid_args)
			call filter(filtered_args, {_, v -> v[:l] ==# a:lead})
			if !empty(filtered_args)
				return filtered_args
			endif
		endif
		return valid_args
	endfunction

	command! -nargs=? -complete=customlist,JaqCompletion Jaq :lua require('jaq-nvim').Jaq(<f-args>)
	
	" プロセス管理コマンド (by totochi-2022)
	command! JaqKillCurrent :lua require('jaq-nvim').kill_current()
	command! JaqKillAll :lua require('jaq-nvim').kill_all()
	command! JaqList :lua require('jaq-nvim').list_processes()
]]
