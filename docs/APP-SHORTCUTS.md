# ChatGPT and Claude actions

On a Work key, choose **ChatGPT or Claude shortcut** from **Mac action → Action**, then pick the command by name. The dropdown stores a portable action, so the choice is included in the existing iCloud settings sync. It does not change the keyboard’s layers or the knob.

Mac actions pause whenever KLAWOS Studio is the frontmost app, including on the key-combinations page. Reserved F13–F20 keys pass through to the editor while you work. Actions resume when you switch to another app; the helper itself stays on.

The ChatGPT choices are Quick Chat (Option + Space), New conversation (Command + N), Show or hide sidebar (Command + B), and Open browser (Command + Shift + B). Quick Chat uses ChatGPT’s default shortcut; if you changed it in ChatGPT, use **Custom keyboard shortcut**. New conversation follows whichever ChatGPT view is open, including Chat, Work, or Codex.

The Claude choices are New chat, New Code session, Next/previous Code session, Show or hide changes, and Show or hide browser. New chat uses Claude’s supported `claude://claude.ai/new` link. The Code commands work in Claude’s Code view. KLAWOS brings the target app forward before sending an app-specific key combination. If that app is absent or cannot be activated, the action reports a failure instead of sending the combination to another app.

The displayed key names are friendly labels. Underlying Vial codes and saved project data remain unchanged. The key chooser excludes ambiguous labels rather than guessing which code they mean; advanced codes can still be entered directly.

Sources checked on 14 October 2026: [ChatGPT Quick Chat](https://help.openai.com/en/articles/9275200-using-the-chatgpt-macos-app), [ChatGPT built-in browser](https://help.openai.com/en/articles/20001277-using-the-built-in-browser-in-the-chatgpt-desktop-app), [Claude Code desktop shortcuts](https://code.claude.com/docs/en/desktop), and [Claude new-chat links](https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link). ChatGPT’s New conversation and sidebar combinations were also checked in the installed desktop app command definitions.
