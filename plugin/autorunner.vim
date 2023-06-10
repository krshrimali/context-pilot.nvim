" nvim-autorunner
" Author: Kushashwa Ravi Shrimali (kushashwaravishrimali@gmail.com)

command! ContextPilotContexts lua require('context_gpt').get_topn_contexts()
command! ContextPilotAuthors lua require('context_gpt').get_topn_authors()
command! ContextPilotContextsCurrentLine lua require('context_gpt').get_topn_contexts_current_line()
command! ContextPilotAuthorsCurrentLine lua require('context_gpt').get_topn_authors_current_line()
