"""
" ContextPilot.nvim
" Author: Kushashwa Ravi Shrimali
command! ContextPilotContexts lua require('context_gpt_v2').get_topn_contexts()
command! ContextPilotContextsCurrentLine lua require('context_gpt_v2').get_topn_contexts_current_line()
command! ContextPilotStartIndexing lua require('context_gpt_v2').start_indexing()
command -range ContextPilotQueryRange lua require('context_gpt_v2').query_context_for_range(<line1>, <line2>)
