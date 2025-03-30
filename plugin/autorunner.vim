" nvim-autorunner
" Author: Kushashwa Ravi Shrimali (kushashwaravishrimali@gmail.com)

command! ContextPilotContexts lua require('context_gpt_v2').get_topn_contexts()
command! ContextPilotAuthors lua require('context_gpt_v2').get_topn_authors()
command! ContextPilotContextsCurrentLine lua require('context_gpt_v2').get_topn_contexts_current_line()
command! ContextPilotAuthorsCurrentLine lua require('context_gpt_v2').get_topn_authors_current_line()
command! -range ContextPilotContextsRange lua require('context_gpt_v2').get_topn_contexts_range(<line1>, <line2>)
command! -range ContextPilotAuthorsRange lua require('context_gpt_v2').get_topn_authors_range(<line1>, <line2>)
command! -range ContextPilotQueryRange lua require('context_gpt_v2').query_context_for_range(<line1>, <line2>)
