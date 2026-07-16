return {
  {
    "github/copilot.vim",
    -- opts = {},
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      vim.cmd([[
        let g:copilot_no_tab_map = v:true
        imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
      ]])
    end
  }
}
